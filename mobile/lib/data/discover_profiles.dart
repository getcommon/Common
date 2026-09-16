import '../models/user_profile.dart';
import '../services/proximity_service.dart';

/// Temporary, production-shaped content for the first Discover profile.
/// Keeping it here makes visual and content iteration independent from matching.
class DiscoverProfile {
  const DiscoverProfile({
    required this.profile,
    this.age,
    required this.distanceLabel,
    required this.sharedInterests,
    required this.compatibilityLabel,
  });

  final UserProfile profile;
  final int? age;
  final String distanceLabel;
  final List<String> sharedInterests;
  final String compatibilityLabel;

  /// Shapes an eligible server-side match for the public profile presentation.
  factory DiscoverProfile.fromMatch(ProximityMatch match) {
    final interestCount = match.commonInterests.length;
    return DiscoverProfile(
      profile: match.userProfile,
      distanceLabel: _coarseDistanceLabel(match.distanceKm),
      sharedInterests: match.commonInterests,
      compatibilityLabel: interestCount == 1
          ? 'You share an interest'
          : 'You share $interestCount interests',
    );
  }

  static String _coarseDistanceLabel(double distanceKm) {
    const milesPerKilometer = 0.621371;
    final miles = distanceKm * milesPerKilometer;
    if (miles < 0.3) return 'Under 0.3 mi away';
    if (miles < 0.5) return 'Under 0.5 mi away';
    return 'Under 1 mi away';
  }
}

final erenDiscoverProfile = DiscoverProfile(
  profile: UserProfile(
    uid: 'eren-discover-demo',
    displayName: 'Eren',
    photoUrl: null,
    bio:
        'Trying to make a ritual of Sunday walks, small bookstores, and cooking something new for friends.',
    interests: const [
      'Independent bookstores',
      'Long walks',
      'Cooking',
      'Live music',
      'Film photography',
    ],
    createdAt: DateTime(2026, 1, 12),
    updatedAt: DateTime(2026, 9, 15),
  ),
  age: 27,
  distanceLabel: 'Under 0.3 mi away',
  sharedInterests: const ['Independent bookstores', 'Long walks', 'Cooking'],
  compatibilityLabel: 'You have a lot in common',
);
