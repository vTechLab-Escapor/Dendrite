import 'package:drift/drift.dart';

/// Fallback used when neither `dart:io` nor the web platform is available.
/// In practice this is never reached — [openConnection] is resolved at compile
/// time to either `native.dart` or `web.dart` via conditional imports.
DatabaseConnection openConnection() => throw UnsupportedError(
    'No Dendrite database implementation exists for this platform.');
