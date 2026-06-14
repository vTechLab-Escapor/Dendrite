import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Native (Android / iOS / desktop) connection: a file-backed SQLite database
/// in the app documents directory, opened lazily so the path lookup can be
/// async.
DatabaseConnection openConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dendrite.db'));
    return DatabaseConnection(NativeDatabase(file));
  }));
}
