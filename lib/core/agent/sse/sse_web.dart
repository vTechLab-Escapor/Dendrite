import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Headers the browser refuses to let scripts set on a fetch/XHR request.
/// Attempting to set them throws, so we drop them on the web.
const _forbiddenHeaders = {
  'accept-encoding',
  'content-length',
  'connection',
  'host',
};

/// Web SSE transport. Browsers can't use `dart:io`, so we POST through
/// `package:http`. Note: true token streaming and cross-origin calls to AI
/// providers are subject to the browser's fetch + CORS rules; the offline mock
/// (no API key) is the reliable in-browser demo path.
Stream<String> openSseStream({
  required Uri uri,
  required Map<String, String> headers,
  required String body,
}) async* {
  final client = http.Client();
  try {
    final request = http.Request('POST', uri);
    headers.forEach((key, value) {
      if (!_forbiddenHeaders.contains(key.toLowerCase())) {
        request.headers[key] = value;
      }
    });
    request.body = body;

    final response = await client.send(request);
    if (response.statusCode != 200) {
      final errBody = await response.stream.bytesToString();
      throw Exception('API Request Failed (${response.statusCode}): $errBody');
    }

    yield* response.stream.transform(utf8.decoder);
  } finally {
    client.close();
  }
}
