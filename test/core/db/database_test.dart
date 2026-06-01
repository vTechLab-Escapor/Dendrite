import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:dendrite/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Should insert messages and fetch lineage/search correctly', () async {
    // Insert Root node
    await db.into(db.messages).insert(const MessagesCompanion(
      id: Value('root'),
      chatId: Value('chat-1'),
      role: Value('user'),
      content: Value('Hello, this is the root prompt.'),
    ));

    // Insert Branched child
    await db.into(db.messages).insert(const MessagesCompanion(
      id: Value('child-1'),
      parentId: Value('root'),
      chatId: Value('chat-1'),
      role: Value('assistant'),
      content: Value('Here is some nested text with full-text search indexable stuff.'),
    ));

    // Test ancestors path
    final path = await db.getAncestors('child-1');
    expect(path.length, 2);
    expect(path[0].id, 'root');
    expect(path[1].id, 'child-1');

    // Test search
    final searchResult = await db.searchMessages('indexable');
    expect(searchResult.length, 1);
    expect(searchResult[0].id, 'child-1');
  });
}
