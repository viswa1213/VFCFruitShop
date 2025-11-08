// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fruit_shop/main.dart';

void main() {
  testWidgets('App boots to Login and can navigate to Register', (
    tester,
  ) async {
    // Build app
    await tester.pumpWidget(const MyApp());

    // We should see the app branding on Login page
    expect(find.text('Fruit Shop'), findsWidgets);
    expect(find.text('Login'), findsOneWidget);

    // Navigate to Register page via the link
    await tester.tap(find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();

    // Register page should be visible (AppBar title 'Register')
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Register')),
      findsOneWidget,
    );
  });
}
