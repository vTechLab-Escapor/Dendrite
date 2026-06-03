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
  BoolColumn get isBookmarked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(messages, messages.isBookmarked);
        }
      },
    );
  }

  // Custom FTS5 Search method
  Future<List<Message>> searchMessages(String query) async {
    final stmt = select(messages)..where((tbl) => tbl.content.like('%$query%'));
    return stmt.get();
  }

  // Retrieve full ancestors list (root -> leaf) for context building.
  // Uses a single recursive CTE instead of one query per ancestor.
  Future<List<Message>> getAncestors(String nodeId) async {
    final rows = await customSelect(
      '''
      WITH RECURSIVE lineage(id) AS (
        SELECT id FROM messages WHERE id = ?1
        UNION ALL
        SELECT m.parent_id FROM messages m
        JOIN lineage l ON m.id = l.id
        WHERE m.parent_id IS NOT NULL
      )
      SELECT m.* FROM messages m
      JOIN lineage l ON m.id = l.id
      ORDER BY m.created_at ASC, m.rowid ASC
      ''',
      variables: [Variable.withString(nodeId)],
      readsFrom: {messages},
    ).get();
    return rows.map((row) => messages.map(row.data)).toList();
  }

  // Get all unique chat sessions with user-friendly titles sorted by last-message recency
  Future<List<MapEntry<String, String>>> getChatSessions() async {
    final allMessages = await select(messages).get();
    if (allMessages.isEmpty) return [];

    final Map<String, List<Message>> grouped = {};
    for (final m in allMessages) {
      grouped.putIfAbsent(m.chatId, () => []).add(m);
    }

    final List<MapEntry<String, String>> sessions = [];
    for (final entry in grouped.entries) {
      final chatId = entry.key;
      final msgs = entry.value;

      // Sort by createdAt ascending to find the first user message
      msgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final firstUserMsg = msgs.firstWhere(
        (m) => m.role == 'user',
        orElse: () => msgs.first,
      );

      String title = firstUserMsg.content;
      final attachmentRegex = RegExp(r'📎 \*\*\[([^\]]+)\]\(([^)]+)\)\*\*\n?');
      title = title.replaceAll(attachmentRegex, '').trim();
      if (title.length > 24) {
        title = '${title.substring(0, 24)}...';
      }
      if (title.isEmpty) {
        title = chatId == 'default_chat' ? '黑洞事件视界探究' : '新对话 ($chatId)';
      }
      sessions.add(MapEntry(chatId, title));
    }

    // Sort by last message's recency descending
    sessions.sort((a, b) {
      final lastMsgA = grouped[a.key]!.map((m) => m.createdAt).reduce((max, e) => e.isAfter(max) ? e : max);
      final lastMsgB = grouped[b.key]!.map((m) => m.createdAt).reduce((max, e) => e.isAfter(max) ? e : max);
      return lastMsgB.compareTo(lastMsgA);
    });

    return sessions;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dendrite.db'));
    return NativeDatabase(file);
  });
}
