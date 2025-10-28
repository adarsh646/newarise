import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:arise/main.dart' as app;
import 'package:arise/login_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login flow', () {
    testWidgets('renders login screen and validates inputs', (tester) async {
      app.main();
      // Wait for navigation from splash to login (up to ~20s)
      final loginTitle = find.text('Login');
      final loginByType = find.byType(LoginScreen);
      for (int i = 0; i < 200; i++) {
        if (loginTitle.evaluate().isNotEmpty || loginByType.evaluate().isNotEmpty) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Expect Login screen is visible by title or type
      expect(loginTitle.evaluate().isNotEmpty || loginByType.evaluate().isNotEmpty, true);

      // Find fields and button
      final emailField = find.widgetWithText(TextFormField, 'Email');
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      final loginButton = find.widgetWithText(ElevatedButton, 'Login');

      expect(emailField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(loginButton, findsOneWidget);

      // Enter invalid inputs
      await tester.enterText(emailField, 'bad');
      await tester.enterText(passwordField, '123');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Expect validation errors
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);

      // Fix email only
      await tester.enterText(emailField, 'user@example.com');
      await tester.pumpAndSettle();

      // Password still short, expect its error
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);

      // Do not actually trigger real auth in integration test here
    });
  });
}
