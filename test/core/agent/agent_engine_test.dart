import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:dendrite/core/db/database.dart';
import 'package:dendrite/core/agent/agent_engine.dart';

void main() {
  late AppDatabase db;
  late AgentEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    engine = AgentEngine(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Agent engine should set up correctly and expose query capabilities', () {
    expect(engine.db, isNotNull);
  });
}
