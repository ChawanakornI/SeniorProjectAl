// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:allcare/features/login/loading_screen.dart';
import 'package:allcare/features/login/login_screen.dart';

void main() {
  testWidgets('Loading screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingScreen()));

    expect(find.byType(LoadingScreen), findsOneWidget);
  });

  testWidgets('Login screen renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('SIGN IN'), findsOneWidget);
  });
}
