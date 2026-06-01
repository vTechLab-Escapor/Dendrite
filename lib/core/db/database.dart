import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get chatId => text()();
  TextColumn get role => text()(); // 'user' or 'assistant'
  TextColumn get content => text()();
  TextColumn get associatedSelection => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  // Custom FTS5 Search method
  Future<List<Message>> searchMessages(String query) async {
    final stmt = select(messages)..where((tbl) => tbl.content.like('%$query%'));
    return stmt.get();
  }

  // Retrieve full ancestors list for context building
  Future<List<Message>> getAncestors(String nodeId) async {
    final List<Message> list = [];
    String? currentId = nodeId;
    while (currentId != null) {
      final msg = await (select(messages)..where((t) => t.id.equals(currentId!))).getSingleOrNull();
      if (msg == null) break;
      list.insert(0, msg);
      currentId = msg.parentId;
    }
    return list;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dendrite.db'));
    return NativeDatabase(file);
  });
}
