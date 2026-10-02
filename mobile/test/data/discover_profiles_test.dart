import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/discover_profiles.dart';
import 'package:mobile/models/user_profile.dart';

void main() {
  test('missing optional top shared interests fall back to an empty list', () {
    final profile = DiscoverProfile(
      profile: UserProfile(
        uid: 'member',
        interests: const [],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      distanceLabel: 'Under 0.5 mi away',
      sharedInterests: const ['Reading'],
      topSharedInterests: null,
      compatibilityLabel: 'You share an interest',
    );

    expect(profile.topSharedInterests, isEmpty);
  });
}
