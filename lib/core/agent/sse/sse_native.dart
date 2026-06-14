import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Native SSE transport using `dart:io` [HttpClient] for true real-time chunk
/// delivery — this deliberately avoids the Android `HttpURLConnection`
/// buffering that stalls `package:http` on streamed responses.
///
/// Yields raw UTF-8-decoded chunks of the response body; SSE line parsing is
/// the caller's responsibility.
Stream<String> openSseStream({
  required Uri uri,
  required Map<String, String> headers,
  required String body,
}) async* {
  final httpClient = HttpClient();
  httpClient.connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await httpClient.postUrl(uri);
    headers.forEach((key, value) => request.headers.set(key, value));

    final bodyBytes = utf8.encode(body);
    request.headers.set('Content-Length', bodyBytes.length.toString());
    request.add(bodyBytes);

    final response = await request.close();
    if (response.statusCode != 200) {
      final errBody = await response.transform(utf8.decoder).join();
      throw Exception('API Request Failed (${response.statusCode}): $errBody');
    }

    yield* response.transform(utf8.decoder);
  } finally {
    httpClient.close();
  }
}
