// End-to-end on-device test of the FULL ingestion feature: a pasted arXiv /
// GitHub URL -> confirm -> fetch over HTTPS -> seed a fresh tree -> fan out one
// analysis branch per angle, each answered by the local MNN server.
//
// Driven by tool/wsa/run_e2e.sh (fills in host IP + model). GitHub uses a blob
// URL on purpose: the raw CDN has no API rate limit (repo metadata does — supply
// --dart-define=DENDRITE_GITHUB_TOKEN=... for repo-root URLs).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dendrite/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> ingest(
    WidgetTester tester,
    String url, {
    required int minBranches,
    required int minAnswered,
  }) async {
    app.main();

    final input = find.byKey(const Key('composer-input'));
    await _until(tester, () => input.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 25));
    expect(input, findsOneWidget, reason: 'composer should be visible');

    // Type the URL and submit -> the confirm dialog should appear.
    await tester.enterText(input, url);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('send-button')));

    final analyze = find.text('Analyze');
    await _until(tester, () => analyze.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 15));
    expect(analyze, findsOneWidget,
        reason: 'ingest confirm dialog should appear for $url');
    await tester.tap(analyze);

    // Fetch + root + N branches, each answered by MNN. Poll the tree summary.
    final summary = find.byKey(const Key('tree-summary'), skipOffstage: false);
    int branches = 0, answered = 0, nodes = 0;
    await _until(
      tester,
      () {
        final w = tester.widgetList<Text>(summary);
        if (w.isEmpty) return false;
        final m = _parse(w.first.data ?? '');
        nodes = m['nodes'] ?? 0;
        answered = m['assistant'] ?? 0;
        branches = m['branches'] ?? 0;
        return branches >= minBranches && answered >= minAnswered;
      },
      timeout: const Duration(minutes: 7),
      step: const Duration(seconds: 1),
    );

    expect(branches, greaterThanOrEqualTo(minBranches),
        reason: 'should fan out $minBranches analysis branches');
    expect(answered, greaterThanOrEqualTo(minAnswered),
        reason: 'root + branches should all have non-empty MNN answers');
    debugPrint('INGEST OK $url -> nodes=$nodes branches=$branches answered=$answered');
  }

  testWidgets('arXiv paper -> full multi-branch analysis', (tester) async {
    // root + 5 analytical branches all answered.
    await ingest(tester, 'https://arxiv.org/abs/1706.03762',
        minBranches: 5, minAnswered: 6);
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('GitHub source file -> full multi-branch analysis', (tester) async {
    // File path -> 4 branches; root + 4 answered. (raw CDN: no API rate limit)
    await ingest(
        tester, 'https://github.com/karpathy/micrograd/blob/master/README.md',
        minBranches: 4, minAnswered: 5);
  }, timeout: const Timeout(Duration(minutes: 15)));
}

Map<String, int> _parse(String s) {
  final out = <String, int>{};
  for (final part in s.split(';')) {
    final kv = part.split('=');
    if (kv.length == 2) out[kv[0]] = int.tryParse(kv[1]) ?? 0;
  }
  return out;
}

Future<void> _until(
  WidgetTester tester,
  bool Function() cond, {
  required Duration timeout,
  Duration step = const Duration(milliseconds: 400),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (cond()) return;
    await tester.pump(step);
  }
}
