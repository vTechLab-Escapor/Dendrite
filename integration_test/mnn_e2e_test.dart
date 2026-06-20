// End-to-end test: drives the real Dendrite app on a device (WSA) and asserts a
// chat round-trip against the local MNN OpenAI-compatible server.
//
// Run (from tool/wsa/run_e2e.sh, which fills in the host IP):
//   flutter test integration_test/mnn_e2e_test.dart \
//     -d 127.0.0.1:58526 \
//     --dart-define=DENDRITE_E2E=true \
//     --dart-define=DENDRITE_BASE_URL=http://172.29.224.1:8080/v1 \
//     --dart-define=DENDRITE_MODEL=Qwen2.5-0.5B-Instruct-MNN
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dendrite/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat round-trip against the local MNN server', (tester) async {
    app.main();

    // Wait for DB init + first frame; the composer appears once initialized.
    final input = find.byKey(const Key('composer-input'));
    await _pumpUntil(tester, () => input.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 20));
    expect(input, findsOneWidget, reason: 'composer should be visible');

    // Send a prompt.
    await tester.enterText(input, 'In one sentence, what is a black hole?');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('send-button')));

    // Poll the offstage mirror until the MNN reply streams in.
    // skipOffstage:false — the mirror lives inside an Offstage, which the
    // default finder would skip.
    final mirror = find.byKey(const Key('assistant-latest'), skipOffstage: false);
    String latest = '';
    await _pumpUntil(
      tester,
      () {
        final widgets = tester.widgetList<Text>(mirror);
        if (widgets.isEmpty) return false;
        latest = widgets.first.data ?? '';
        return latest.trim().isNotEmpty;
      },
      timeout: const Duration(seconds: 90),
    );

    expect(latest.trim(), isNotEmpty,
        reason: 'MNN server should have returned a non-empty response');
    debugPrint('MNN E2E reply: ${latest.replaceAll('\n', ' ')}');
  });
}

/// Pumps frames until [condition] is true or [timeout] elapses (pumpAndSettle is
/// unusable here — streaming + DB timers never settle).
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 400));
  }
}
