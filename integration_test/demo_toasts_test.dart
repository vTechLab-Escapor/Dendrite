// Re-capture driver for the two beats that need a legible toast (shot4 edge<->cloud
// switch, shot6 export). Run with DENDRITE_DEMO=true so toasts hold ~6s, and
// WITHOUT DENDRITE_BASE_URL so the offline mock builds a tree fast.
//
//   flutter test integration_test/demo_toasts_test.dart -d 127.0.0.1:58526 \
//     --dart-define=DENDRITE_E2E=true --dart-define=DENDRITE_DEMO=true
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dendrite/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('toast beats (record me)', (tester) async {
    app.main();
    final input = find.byKey(const Key('composer-input'));
    await _until(tester, () => input.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 25));

    // Build a small tree fast (mock) so export has something to export.
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
      return m != null && int.parse(m.group(1)!) >= 3;
    }, timeout: const Duration(seconds: 60));
    await _hold(tester, const Duration(seconds: 2));

    // BEAT shot4 — Edge<->Cloud switch with held, descriptive toasts.
    debugPrint('BEAT 4 toggle');
    await _tapText(tester, '云端'); // cloud -> edge: "已切换至本地推理 — 离线·隐私·零成本"
    await _hold(tester, const Duration(seconds: 8));
    await _tapText(tester, '本地'); // edge -> cloud: "已切换至云端推理 — 最强能力"
    await _hold(tester, const Duration(seconds: 8));

    // BEAT shot6 — export to Markdown with held toast.
    debugPrint('BEAT 6 export');
    await _tapIcon(tester, Icons.ios_share);
    await _hold(tester, const Duration(seconds: 9));

    debugPrint('TOAST BEATS DONE');
  }, timeout: const Timeout(Duration(minutes: 5)));
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
