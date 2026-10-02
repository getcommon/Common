import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/auth_service.dart';

void main() {
  String messageFor(String code) =>
      AuthFlowException.fromFirebase(FirebaseAuthException(code: code)).message;

  test('maps registration conflicts to the account-linking guidance', () {
    expect(
      messageFor('email-already-in-use'),
      contains('Sign in with the method'),
    );
  });

  test('maps invalid sign-in credentials to a safe message', () {
    expect(
      messageFor('invalid-credential'),
      'That email or password is incorrect.',
    );
  });

  test('maps weak password errors to creation guidance', () {
    expect(messageFor('weak-password'), contains('at least 8 characters'));
  });

  test('maps reset throttling errors to a retry message', () {
    expect(messageFor('too-many-requests'), contains('Please wait'));
  });
}
