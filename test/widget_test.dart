// Basic smoke test for the Dendrite app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dendrite/main.dart';

void main() {
  testWidgets('DendriteApp builds and shows initial loading state',
      (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const DendriteApp());

    // The chat screen shows a loading spinner while the database initializes.
    // (We don't pumpAndSettle here because DB/settings init relies on
    // platform plugins that aren't available in the widget-test environment.)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
