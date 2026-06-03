import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:dendrite/core/db/database.dart';

/// The wire format a provider speaks. Most OpenAI-compatible providers
/// (NVIDIA, ModelScope, OpenAI, Grok, Xiaomi) share one dialect; Anthropic and
/// Gemini each use their own request shape and SSE event schema.
enum ApiDialect { openai, anthropic, gemini }

class AgentEngine {
  final AppDatabase db;

  AgentEngine({required this.db});

  static const String _systemPrompt =
      'You are a helpful AI assistant. For every response, you MUST first think step-by-step inside <think>...</think> tags, then provide your final answer after the closing </think> tag. This thinking process helps you reason more carefully.';

  static ApiDialect dialectFor(String provider) {
    switch (provider) {
      case 'anthropic':
        return ApiDialect.anthropic;
      case 'gemini':
        return ApiDialect.gemini;
      default:
        return ApiDialect.openai;
    }
  }

  /// SSE streaming using dart:io HttpClient for true real-time chunk delivery
  /// Bypasses the Android HttpURLConnection buffering that plagues package:http
  Stream<String> submitQueryStream({
    required String chatId,
    required String userMsgId,
    required String provider,
    required String providerUrl,
    required String apiKey,
    required String modelName,
  }) async* {
    // Gather full lineage context using the already-inserted userMsgId.
    final contextHistory = await db.getAncestors(userMsgId);

    // Common {role, content} payload with selection context prepended.
    final messages = contextHistory
        .map((m) => {
              'role': m.role,
              'content': m.associatedSelection != null
                  ? '[Context: "${m.associatedSelection}"]\n${m.content}'
                  : m.content,
            })
        .toList();

    final dialect = dialectFor(provider);

    // dart:io HttpClient for true streaming (avoids Android buffering). Wrapped
    // in try/finally so the client is always closed — including on cancel.
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 30);

    try {
      final uri =
          Uri.parse(_endpoint(dialect, providerUrl, modelName, apiKey));
      final httpRequest = await httpClient.postUrl(uri);
      _applyHeaders(httpRequest, dialect, apiKey);

      final bodyBytes =
          utf8.encode(jsonEncode(_buildBody(dialect, modelName, messages)));
      httpRequest.headers.set('Content-Length', bodyBytes.length.toString());
      httpRequest.add(bodyBytes);

      final httpResponse = await httpRequest.close();

      if (httpResponse.statusCode != 200) {
        final body = await httpResponse.transform(utf8.decoder).join();
        throw Exception(
            'API Request Failed (${httpResponse.statusCode}): $body');
      }

      // All three dialects deliver Server-Sent Events ("data: <json>" lines);
      // only the per-chunk JSON shape differs (see _extractDelta).
      String buffer = '';
      int yieldCount = 0;

      void parseLine(String line, List<String> out) {
        if (line.isEmpty) return;
        if (!line.startsWith('data:')) return;
        final dataContent = line.substring(5).trim();
        if (dataContent.isEmpty || dataContent == '[DONE]') return;
        try {
          final parsed = jsonDecode(dataContent);
          final delta = _extractDelta(dialect, parsed);
          if (delta != null && delta.isNotEmpty) out.add(delta);
        } catch (_) {}
      }

      try {
        await for (final chunk in httpResponse.transform(utf8.decoder)) {
          buffer += chunk;
          while (buffer.contains('\n')) {
            final lineEnd = buffer.indexOf('\n');
            final line = buffer.substring(0, lineEnd).trim();
            buffer = buffer.substring(lineEnd + 1);

            final out = <String>[];
            parseLine(line, out);
            for (final item in out) {
              yieldCount++;
              yield item;
            }
          }
        }
      } catch (e) {
        if (yieldCount == 0) rethrow;
      }

      // Parse residual buffer.
      if (buffer.isNotEmpty) {
        final out = <String>[];
        parseLine(buffer.trim(), out);
        for (final item in out) {
          yield item;
        }
      }
    } finally {
      httpClient.close();
    }
  }

  String _endpoint(
      ApiDialect dialect, String providerUrl, String modelName, String apiKey) {
    switch (dialect) {
      case ApiDialect.anthropic:
        return '$providerUrl/messages';
      case ApiDialect.gemini:
        // Model goes in the path; key is passed as a query param.
        return '$providerUrl/models/$modelName:streamGenerateContent?alt=sse&key=$apiKey';
      case ApiDialect.openai:
        return '$providerUrl/chat/completions';
    }
  }

  void _applyHeaders(
      HttpClientRequest request, ApiDialect dialect, String apiKey) {
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'text/event-stream');
    request.headers.set('Cache-Control', 'no-cache');
    request.headers.set('Accept-Encoding', 'identity');
    switch (dialect) {
      case ApiDialect.anthropic:
        request.headers.set('x-api-key', apiKey);
        request.headers.set('anthropic-version', '2023-06-01');
        break;
      case ApiDialect.gemini:
        // Authenticated via the URL query string.
        break;
      case ApiDialect.openai:
        request.headers.set('Authorization', 'Bearer $apiKey');
        break;
    }
  }

  Map<String, dynamic> _buildBody(
      ApiDialect dialect, String modelName, List<Map<String, String>> messages) {
    switch (dialect) {
      case ApiDialect.anthropic:
        // System prompt is a top-level field; messages carry only user/assistant.
        return {
          'model': modelName,
          'max_tokens': 4096,
          'system': _systemPrompt,
          'messages': messages,
          'stream': true,
        };
      case ApiDialect.gemini:
        return {
          'systemInstruction': {
            'parts': [
              {'text': _systemPrompt}
            ]
          },
          'contents': messages
              .map((m) => {
                    'role': m['role'] == 'assistant' ? 'model' : 'user',
                    'parts': [
                      {'text': m['content']}
                    ],
                  })
              .toList(),
        };
      case ApiDialect.openai:
        return {
          'model': modelName,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            ...messages,
          ],
          'stream': true,
        };
    }
  }

  String? _extractDelta(ApiDialect dialect, dynamic parsed) {
    switch (dialect) {
      case ApiDialect.anthropic:
        // Streamed text arrives as content_block_delta events.
        if (parsed['type'] == 'content_block_delta') {
          return parsed['delta']?['text'] as String?;
        }
        return null;
      case ApiDialect.gemini:
        return parsed['candidates']?[0]?['content']?['parts']?[0]?['text']
            as String?;
      case ApiDialect.openai:
        return parsed['choices']?[0]?['delta']?['content'] as String?;
    }
  }
}
