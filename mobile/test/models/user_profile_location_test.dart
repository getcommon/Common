import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/user_profile.dart';

void main() {
  test('ignores a legacy visibility-only location map', () {
    final profile = UserProfile.fromMap({
      'uid': 'member',
      'interests': <String>['Reading'],
      'createdAt': 0,
      'updatedAt': 0,
      'location': {'isVisible': false},
    });

    expect(profile.location, isNull);
    expect(profile.isComplete, isTrue);
  });
}
