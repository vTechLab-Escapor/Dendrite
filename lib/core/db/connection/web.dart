import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web connection: a WebAssembly build of sqlite3 persisted through the best
/// storage backend the browser offers (OPFS where available, IndexedDB
/// otherwise). Requires `web/sqlite3.wasm` and `web/drift_worker.js` to be
/// present (see deploy/README.md).
DatabaseConnection openConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'dendrite',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  }));
}
