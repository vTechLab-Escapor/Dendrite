// Per-beat capture driver for the「手机上的创意 AI 挑战赛」final shot-matched cut.
// Run WITHOUT DENDRITE_BASE_URL so the offline mock answers instantly (tree builds
// in ~10s), letting every UI beat be held >= its narration dwell inside one 180s
// screenrecord. The REAL on-device-analysis beat (shot 5) comes from wsa_walk_raw.
//
//   flutter test integration_test/demo_beats_test.dart -d 127.0.0.1:58526 \
//     --dart-define=DENDRITE_E2E=true
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dendrite/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('per-beat capture (record me)', (tester) async {
    app.main();
    final input = find.byKey(const Key('composer-input'));
    await _until(tester, () => input.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 25));

    // BEAT shot0 — empty state (痛点).
    debugPrint('BEAT 0 empty');
    await _hold(tester, const Duration(seconds: 13));

    // Build a tree fast via mock-backed ingest.
    await tester.enterText(input, 'https://arxiv.org/abs/1706.03762');
    await _hold(tester, const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('send-button')));
    final analyze = find.text('Analyze');
    await _until(tester, () => analyze.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 15));
    await tester.tap(analyze);
    final summary = find.byKey(const Key('tree-summary'), skipOffstage: false);
    await _until(tester, () {
      final w = tester.widgetList<Text>(summary);
      if (w.isEmpty) return false;
      final m = RegExp(r'branches=(\d+)').firstMatch(w.first.data ?? '');
      return m != null && int.parse(m.group(1)!) >= 4;
    }, timeout: const Duration(seconds: 60));

    // BEAT shot1 — branched knowledge tree.
    debugPrint('BEAT 1 tree');
    await _hold(tester, const Duration(seconds: 13));

    // BEAT shot2 — mind-map.
    await _tapIcon(tester, Icons.account_tree_outlined);
    debugPrint('BEAT 2 mindmap');
    await _hold(tester, const Duration(seconds: 11));
    await _tapIcon(tester, Icons.chat_bubble_outline);
    await _hold(tester, const Duration(seconds: 1));

    // BEAT shot3 — settings (default-backend toggle + local MNN endpoint).
    await _tapIcon(tester, Icons.menu);
    await _hold(tester, const Duration(seconds: 1));
    await _tapIcon(tester, Icons.settings_outlined);
    debugPrint('BEAT 3 settings');
    await _hold(tester, const Duration(seconds: 17));
    await _tapText(tester, '取消');
    await _hold(tester, const Duration(seconds: 1));

    // BEAT shot4 — live Edge<->Cloud chip flip.
    debugPrint('BEAT 4 toggle');
    await _tapText(tester, '云端'); // cloud -> edge
    await _hold(tester, const Duration(seconds: 8));
    await _tapText(tester, '本地'); // edge -> cloud
    await _hold(tester, const Duration(seconds: 8));

    // BEAT shot6 — export to Markdown (toast).
    await _tapIcon(tester, Icons.ios_share);
    debugPrint('BEAT 6 export');
    await _hold(tester, const Duration(seconds: 11));

    // BEAT shot7 — overview (mind-map again).
    await _tapIcon(tester, Icons.account_tree_outlined);
    debugPrint('BEAT 7 overview');
    await _hold(tester, const Duration(seconds: 13));

    debugPrint('BEATS DONE');
  }, timeout: const Timeout(Duration(minutes: 6)));
}

Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  final f = find.byIcon(icon);
  if (f.evaluate().isNotEmpty) await tester.tap(f.first);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (f.evaluate().isNotEmpty) await tester.tap(f.first);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _hold(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _until(WidgetTester tester, bool Function() cond,
    {required Duration timeout}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (cond()) return;
    await tester.pump(const Duration(milliseconds: 400));
  }
}
