import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/auth_service.dart';

void main() {
  test('only the configured reviewer account bypasses email verification', () {
    expect(AuthService.isReviewerTestEmail('test@gmail.com'), isTrue);
    expect(AuthService.isReviewerTestEmail(' TEST@GMAIL.COM '), isTrue);
    expect(AuthService.isReviewerTestEmail('member@example.com'), isFalse);
  });
}
