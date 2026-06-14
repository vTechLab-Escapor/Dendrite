/// Fallback transport — never reached; [openSseStream] is resolved at compile
/// time to the native or web implementation via conditional imports.
Stream<String> openSseStream({
  required Uri uri,
  required Map<String, String> headers,
  required String body,
}) =>
    throw UnsupportedError('No SSE transport exists for this platform.');
