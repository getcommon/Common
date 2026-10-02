import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/constants/proximity_constants.dart';

/// Service for finding nearby users with similar interests
class ProximityService {
  ProximityService._();
  static final instance = ProximityService._();

  final _functions = FirebaseFunctions.instance;

  /// Find nearby users with similar interests
  ///
  /// Parameters:
  /// - currentUserProfile: The current user's profile
  /// - maxDistanceKm: Maximum distance in kilometers (uses user's preference if not specified)
  /// - minCommonInterests: Minimum number of common interests required (default: 1)
  /// - limit: Maximum number of results to return (default: 10)
  Future<List<ProximityMatch>> findNearbyMatches(
    UserProfile currentUserProfile, {
    double? maxDistanceKm,
    int minCommonInterests = kMinCommonInterests,
    int limit = kDefaultResultLimit,
  }) => _findServerMatches();

  /// Stream of nearby matches (real-time updates) - OPTIMIZED
  Stream<List<ProximityMatch>> watchNearbyMatches(
    UserProfile currentUserProfile, {
    double? maxDistanceKm,
    int minCommonInterests = kMinCommonInterests,
    int limit = kDefaultResultLimit,
  }) {
    // Create a controller for immediate start
    final controller = StreamController<List<ProximityMatch>>();

    // Start with immediate search
    _findServerMatches()
        .then((matches) {
          if (!controller.isClosed) controller.add(matches);
        })
        .catchError((error) {
          if (!controller.isClosed) controller.addError(error);
        });

    // Then update every 2 minutes
    final timer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _findServerMatches()
          .then((matches) {
            if (!controller.isClosed) controller.add(matches);
          })
          .catchError((error) {
            if (!controller.isClosed) controller.addError(error);
          });
    });

    // Cancel timer and close controller when the stream listener is removed
    controller.onCancel = () {
      timer.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Future<List<ProximityMatch>> _findServerMatches() async {
    final response = await _functions
        .httpsCallable('findNearbyMatches')
        .call<Map<String, dynamic>>({});
    final rawMatches = (response.data['matches'] as List? ?? const []);
    return rawMatches.map((rawMatch) {
      final match = Map<String, dynamic>.from(rawMatch as Map);
      final profile = Map<String, dynamic>.from(
        match['userProfile'] as Map? ?? const {},
      );
      return ProximityMatch(
        userProfile: UserProfile(
          uid: profile['uid'] as String,
          displayName: profile['displayName'] as String?,
          photoUrl: profile['photoUrl'] as String?,
          featuredPhotoUrl: profile['featuredPhotoUrl'] as String?,
          photoMoments: (profile['photoMoments'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (moment) => ProfilePhotoMoment.fromMap(
                  Map<String, dynamic>.from(moment),
                ),
              )
              .toList(),
          bio: profile['bio'] as String?,
          interests:
              (profile['interests'] as List?)?.cast<String>() ?? const [],
          vibeTags: (profile['vibeTags'] as List?)?.cast<String>() ?? const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        // The server returns a representative value for a coarse distance band,
        // never another member's calculated distance.
        distanceKm: (match['distanceKm'] as num).toDouble(),
        commonInterests:
            (match['commonInterests'] as List?)?.cast<String>() ?? const [],
        topSharedInterests:
            (match['topSharedInterests'] as List?)?.cast<String>() ?? const [],
        matchScore: (match['matchScore'] as num).toDouble(),
      );
    }).toList();
  }

  /// Forces an immediate server-authoritative refresh.
  Future<List<ProximityMatch>> refreshMatches(
    UserProfile currentUserProfile, {
    double? maxDistanceKm,
    int minCommonInterests = kMinCommonInterests,
    int limit = kDefaultResultLimit,
  }) async {
    return _findServerMatches();
  }
}

/// Represents a proximity match with another user
class ProximityMatch {
  final UserProfile userProfile;
  final double distanceKm;
  final List<String> commonInterests;
  final double matchScore;

  const ProximityMatch({
    required this.userProfile,
    required this.distanceKm,
    required this.commonInterests,
    List<String>? topSharedInterests,
    required this.matchScore,
  }) : _topSharedInterests = topSharedInterests;

  // Matches can outlive a hot reload and callable payloads from an earlier
  // deploy may not include this optional ranking detail.
  final List<String>? _topSharedInterests;
  List<String> get topSharedInterests => _topSharedInterests ?? const [];

  /// Get formatted distance string
  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    } else {
      return '${distanceKm.toStringAsFixed(1)}km';
    }
  }

  /// Get match percentage
  int get matchPercentage {
    return (matchScore * 100).round();
  }
}
