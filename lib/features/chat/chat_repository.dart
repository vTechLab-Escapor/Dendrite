import 'package:drift/drift.dart';
import 'package:dendrite/core/db/database.dart';

/// Thin persistence layer over [AppDatabase] for chat messages, so the UI
/// doesn't build drift companions / queries inline.
class ChatRepository {
  final AppDatabase _db;
  ChatRepository(this._db);

  /// All nodes belonging to a chat, in insertion order.
  Future<List<Message>> nodesInChat(String chatId) {
    return (_db.select(_db.messages)..where((t) => t.chatId.equals(chatId))).get();
  }

  /// Full ancestor lineage (root -> leaf) for a node.
  Future<List<Message>> ancestors(String nodeId) => _db.getAncestors(nodeId);

  /// Full-text-ish search across all messages.
  Future<List<Message>> search(String query) => _db.searchMessages(query);

  /// Distinct chat sessions with display titles, most-recent first.
  Future<List<MapEntry<String, String>>> chatSessions() => _db.getChatSessions();

  /// Insert (or upsert) a single message.
  Future<void> insertMessage({
    required String id,
    String? parentId,
    required String chatId,
    required String role,
    required String content,
    String? associatedSelection,
    bool isBookmarked = false,
    bool upsert = false,
  }) {
    final companion = MessagesCompanion.insert(
      id: id,
      parentId: Value(parentId),
      chatId: chatId,
      role: role,
      content: content,
      associatedSelection: Value(associatedSelection),
      isBookmarked: Value(isBookmarked),
    );
    final into = _db.into(_db.messages);
    return upsert ? into.insertOnConflictUpdate(companion) : into.insert(companion);
  }

  /// Toggle/set the bookmark flag on a message.
  Future<void> setBookmark(Message message, bool value) {
    return _db.update(_db.messages).replace(message.copyWith(isBookmarked: value));
  }
}
