import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/pages/email_auth_page.dart';

void main() {
  Widget subject() => const MaterialApp(home: EmailAuthPage());

  testWidgets('email sign-in exposes password recovery', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('Sign in with email'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('account creation requires password confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });
}
