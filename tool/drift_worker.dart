import 'package:drift/wasm.dart';

/// Compiled to `web/drift_worker.js` (see deploy/README.md). Drives the
/// background worker that hosts the WebAssembly sqlite3 database for the web
/// build. Regenerate with:
///   dart compile js -O4 -o web/drift_worker.js tool/drift_worker.dart
void main() {
  WasmDatabase.workerMainForOpen();
}
