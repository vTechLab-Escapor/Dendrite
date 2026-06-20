// Choreographed on-device demo walkthrough for the「手机上的创意 AI 挑战赛」video.
// Drives the REAL app on WSA through the feature beats with deliberate real-time
// holds so a parallel `adb screenrecord` captures rich, beat-matched footage:
//   empty state → paste arXiv link → confirm → multi-branch tree builds live →
//   hold → export Markdown (toast) → mind-map view → back → edge↔cloud chip flip.
//
// Run (with screenrecord running in parallel):
//   flutter test integration_test/demo_walkthrough_test.dart -d 127.0.0.1:58526 \
//     --dart-define=DENDRITE_E2E=true \
//     --dart-define=DENDRITE_BASE_URL=http://172.29.224.1:8080/v1 \
//     --dart-define=DENDRITE_MODEL=Qwen2.5-0.5B-Instruct-MNN
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dendrite/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo walkthrough (record me)', (tester) async {
    app.main();

    final input = find.byKey(const Key('composer-input'));
    await _until(tester, () => input.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 25));
    await _hold(tester, const Duration(seconds: 3)); // empty state beat

    // --- Paste an arXiv link and confirm analysis ---
    await tester.enterText(input, 'https://arxiv.org/abs/1706.03762');
    await _hold(tester, const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('send-button')));
    final analyze = find.text('Analyze');
    await _until(tester, () => analyze.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 15));
    await _hold(tester, const Duration(seconds: 2)); // confirm dialog beat
    await tester.tap(analyze);

    // --- Multi-branch tree builds live; let it run, then hold on the result ---
    final summary = find.byKey(const Key('tree-summary'), skipOffstage: false);
    await _until(
      tester,
      () {
        final w = tester.widgetList<Text>(summary);
        if (w.isEmpty) return false;
        final s = w.first.data ?? '';
        // Proceed once the tree is visibly branching (>=2); remaining branches
        // keep streaming in the background while the UI beats play. Keeps the
        // whole walkthrough inside one 180s screenrecord.
        final m = RegExp(r'branches=(\d+)').firstMatch(s);
        return m != null && int.parse(m.group(1)!) >= 2;
      },
      timeout: const Duration(minutes: 5),
    );
    await _hold(tester, const Duration(seconds: 6)); // branching tree beat

    // --- Export to Markdown (toast) ---
    await _tapIcon(tester, Icons.ios_share);
    await _hold(tester, const Duration(seconds: 5));

    // --- Mind-map view ---
    await _tapIcon(tester, Icons.account_tree_outlined);
    await _hold(tester, const Duration(seconds: 6));
    await _tapIcon(tester, Icons.chat_bubble_outline); // back to chat
    await _hold(tester, const Duration(seconds: 2));

    // --- Edge ↔ Cloud live toggle (chip shows 本地/云端) ---
    await _tapText(tester, '本地'); // edge -> cloud
    await _hold(tester, const Duration(seconds: 4));
    await _tapText(tester, '云端'); // cloud -> edge
    await _hold(tester, const Duration(seconds: 3));

    debugPrint('DEMO WALKTHROUGH DONE');
  }, timeout: const Timeout(Duration(minutes: 12)));
}

int _answered(String s) {
  final m = RegExp(r'assistant=(\d+)').firstMatch(s);
  return m == null ? 0 : int.parse(m.group(1)!);
}

Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  final f = find.byIcon(icon);
  if (f.evaluate().isNotEmpty) await tester.tap(f.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (f.evaluate().isNotEmpty) await tester.tap(f.first);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Hold the current frame on the real device for [d] of wall-clock time.
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
