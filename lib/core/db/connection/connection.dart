/// Resolves [openConnection] to the right implementation at compile time:
/// `native.dart` when `dart:io` is available, `web.dart` on the web, and the
/// throwing stub otherwise.
export 'unsupported.dart'
    if (dart.library.io) 'native.dart'
    if (dart.library.js_interop) 'web.dart';
