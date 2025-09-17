// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:translation_fiesta_flutter/main.dart';

void main() {
  testWidgets('App starts and displays main page', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FlutterTranslateApp());

    // Verify that the main page is displayed.
    expect(find.text('Flutter Translate'), findsOneWidget);
  });
}
