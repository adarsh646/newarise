import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:arise/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Register flow', () {
    testWidgets('navigate to register and validate fields', (tester) async {
      app.main();
      // Wait for navigation from splash to login (up to ~20s)
      final loginTitle = find.text('Login');
      for (int i = 0; i < 200 && loginTitle.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // On Login, tap Register link
      final registerLink = find.textContaining('Register');
      expect(registerLink, findsWidgets);
      await tester.tap(registerLink.first);

      // Wait for Register screen fields to render
      final emailField = find.widgetWithText(TextFormField, 'Email');
      for (int i = 0; i < 200 && emailField.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Expect Register screen fields
      final usernameField = find.widgetWithText(TextFormField, 'Username');
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      final confirmPasswordField = find.widgetWithText(TextFormField, 'Confirm Password');
      final registerButton = find.widgetWithText(ElevatedButton, 'Register');

      expect(emailField, findsOneWidget);
      expect(usernameField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(confirmPasswordField, findsOneWidget);
      expect(registerButton, findsOneWidget);

      // Trigger validation errors
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Enter invalid email and mismatched passwords
      await tester.enterText(emailField, 'bad');
      await tester.enterText(usernameField, 'ab');
      await tester.enterText(passwordField, '12345');
      await tester.enterText(confirmPasswordField, '54321');
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Check for typical validation messages (match your screen validation)
      expect(find.textContaining('valid email'), findsOneWidget);
      expect(find.textContaining('at least 3 characters'), findsOneWidget);
      expect(find.textContaining('at least 6 characters'), findsWidgets);
      expect(find.textContaining('do not match'), findsOneWidget);

      // Unfocus any active text fields to avoid FocusManager updates after test end
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    });
  });
}
