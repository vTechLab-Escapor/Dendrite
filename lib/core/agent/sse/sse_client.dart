/// Resolves [openSseStream] to the right transport at compile time:
/// `sse_native.dart` (dart:io HttpClient) on mobile/desktop, `sse_web.dart`
/// (package:http) on the web.
export 'sse_unsupported.dart'
    if (dart.library.io) 'sse_native.dart'
    if (dart.library.js_interop) 'sse_web.dart';
