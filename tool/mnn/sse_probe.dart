// Host-side probe that replicates Dendrite's native SSE client
// (lib/core/agent/sse/sse_native.dart) exactly, so we can validate the MNN
// server's streaming contract without a 90s WSA build/run cycle.
//   dart tool/mnn/sse_probe.dart [http://127.0.0.1:8080/v1/chat/completions]
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final uri = Uri.parse(args.isNotEmpty
      ? args[0]
      : 'http://127.0.0.1:8080/v1/chat/completions');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  final req = await client.postUrl(uri);
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Accept', 'text/event-stream');
  final body = utf8.encode(jsonEncode({
    'model': 'probe',
    'stream': true,
    'messages': [
      {'role': 'user', 'content': 'Say hello in 5 words.'}
    ],
  }));
  req.headers.set('Content-Length', body.length.toString());
  req.add(body);

  final resp = await req.close();
  stdout.writeln('status ${resp.statusCode}');
  var total = '';
  var frames = 0;
  final sw = Stopwatch()..start();
  await for (final chunk in resp.transform(utf8.decoder)) {
    for (final raw in chunk.split('\n')) {
      final line = raw.trim();
      if (!line.startsWith('data:')) continue;
      final d = line.substring(5).trim();
      if (d.isEmpty || d == '[DONE]') continue;
      try {
        final j = jsonDecode(d);
        final t = j['choices']?[0]?['delta']?['content'];
        if (t is String) {
          total += t;
          frames++;
        }
      } catch (_) {}
    }
  }
  stdout.writeln('frames=$frames chars=${total.length} in ${sw.elapsedMilliseconds}ms');
  stdout.writeln('reply: ${total.replaceAll('\n', ' ')}');
  client.close();
  exit(total.trim().isEmpty ? 1 : 0);
}
