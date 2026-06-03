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

  group('AgentEngine.dialectFor', () {
    test('routes Anthropic and Gemini to their own dialects', () {
      expect(AgentEngine.dialectFor('anthropic'), ApiDialect.anthropic);
      expect(AgentEngine.dialectFor('gemini'), ApiDialect.gemini);
    });

    test('routes OpenAI-compatible providers to the openai dialect', () {
      for (final p in ['nvidia', 'modelscope', 'openai', 'grok', 'xiaomi', 'unknown']) {
        expect(AgentEngine.dialectFor(p), ApiDialect.openai, reason: p);
      }
    });
  });
}
