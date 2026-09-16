import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:async';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/constants/interest_categories.dart';
import 'package:mobile/constants/proximity_constants.dart';
import 'package:mobile/constants/vibe_tags.dart';

/// Service for finding nearby users with similar interests
class ProximityService {
  ProximityService._();
  static final instance = ProximityService._();

  final _db = FirebaseFirestore.instance;

  // Caching for performance
  final Map<String, List<ProximityMatch>> _matchCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = kMatchCacheExpiry;

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
  }) async {
    // Use user's preferred search radius if not explicitly provided
    final searchRadius =
        maxDistanceKm ?? currentUserProfile.effectiveSearchRadiusKm;
    try {
      // Check cache first
      final cacheKey =
          '${currentUserProfile.uid}_${searchRadius}_$minCommonInterests';
      final cachedMatches = _getCachedMatches(cacheKey);
      if (cachedMatches != null) {
        debugPrint('🚀 Using cached matches: ${cachedMatches.length} results');
        return cachedMatches.take(limit).toList();
      }
      // Check if user has location and interests
      if (currentUserProfile.location?.isVisible != true) {
        debugPrint('User location not visible');
        return [];
      }

      if (currentUserProfile.interests.isEmpty) {
        debugPrint('User has no interests');
        return [];
      }

      final currentGeohash = currentUserProfile.location!.geohash;
      final currentLat = currentUserProfile.location!.latitude;
      final currentLng = currentUserProfile.location!.longitude;

      if (currentLat == null || currentLng == null) {
        debugPrint('User location coordinates not available');
        return [];
      }

      // Get nearby geohashes (expanded search area)
      final nearbyGeohashes = _getNearbyGeohashes(currentGeohash, searchRadius);

      debugPrint('🔍 PROXIMITY SEARCH STARTED');
      debugPrint('📍 Current user: ${currentUserProfile.displayName}');
      debugPrint('📍 Current location: $currentLat, $currentLng');
      debugPrint('📍 Current geohash: $currentGeohash');
      debugPrint('📍 User interests: ${currentUserProfile.interests}');
      debugPrint('🔍 Searching in ${nearbyGeohashes.length} geohash areas');
      debugPrint('🔍 Nearby geohashes: $nearbyGeohashes');

      // OPTIMIZED: Single query with array-contains-any for multiple geohashes
      final List<ProximityMatch> matches = [];

      // Use array-contains-any for efficient multi-geohash search
      final query = await _db
          .collection('users')
          .where('location.geohash', whereIn: nearbyGeohashes)
          .where('location.isVisible', isEqualTo: true)
          .limit(100) // Get more users for filtering
          .get();

      debugPrint('🔍 Single optimized query found ${query.docs.length} users');

      // Pre-compute current user's interest set for O(1) lookups
      final currentInterestsSet = currentUserProfile.interests.toSet();

      for (final doc in query.docs) {
        // Skip current user
        if (doc.id == currentUserProfile.uid) continue;

        try {
          final userProfile = UserProfile.fromMap(doc.data());

          // Check if user has location coordinates
          if (userProfile.location?.latitude == null ||
              userProfile.location?.longitude == null) {
            continue;
          }

          // Calculate distance
          final distance = _calculateDistance(
            currentLat,
            currentLng,
            userProfile.location!.latitude!,
            userProfile.location!.longitude!,
          );

          // Filter by distance
          if (distance > searchRadius) continue;

          // OPTIMIZED: Fast interest matching using sets
          final commonInterests = _getCommonInterestsOptimized(
            currentInterestsSet,
            userProfile.interests,
          );

          // Filter by minimum common interests
          if (commonInterests.length < minCommonInterests) continue;

          // Calculate match score using category-weighted algorithm
          final matchScore = _calculateCategoryWeightedMatchScore(
            currentUserProfile,
            userProfile,
            distance,
          );
          if (!_meetsDiscoverThreshold(distance, matchScore)) continue;

          matches.add(
            ProximityMatch(
              userProfile: userProfile,
              distanceKm: distance,
              commonInterests: commonInterests,
              matchScore: matchScore,
            ),
          );
        } catch (e) {
          debugPrint('Error parsing user profile ${doc.id}: $e');
          continue;
        }
      }

      // If no matches found with geohash, try a broader search
      if (matches.isEmpty) {
        debugPrint(
          '🔍 No matches found with geohash search, trying broader search...',
        );
        final query = await _db
            .collection('users')
            .where('location.isVisible', isEqualTo: true)
            .limit(50) // Get more users for broader search
            .get();

        debugPrint('🔍 Broad search found ${query.docs.length} users');

        for (final doc in query.docs) {
          // Skip current user
          if (doc.id == currentUserProfile.uid) continue;

          try {
            final userProfile = UserProfile.fromMap(doc.data());

            // Check if user has location coordinates
            if (userProfile.location?.latitude == null ||
                userProfile.location?.longitude == null) {
              continue;
            }

            // Calculate distance
            final distance = _calculateDistance(
              currentLat,
              currentLng,
              userProfile.location!.latitude!,
              userProfile.location!.longitude!,
            );

            // A broader query may improve recall, but never expands a person's
            // selected radius or exposes a less-nearby profile.
            if (distance > searchRadius) continue;

            // OPTIMIZED: Fast interest matching using sets
            final commonInterests = _getCommonInterestsOptimized(
              currentInterestsSet,
              userProfile.interests,
            );

            // Filter by minimum common interests
            if (commonInterests.length < minCommonInterests) continue;

            // Calculate match score using category-weighted algorithm
            final matchScore = _calculateCategoryWeightedMatchScore(
              currentUserProfile,
              userProfile,
              distance,
            );
            if (!_meetsDiscoverThreshold(distance, matchScore)) continue;

            matches.add(
              ProximityMatch(
                userProfile: userProfile,
                distanceKm: distance,
                commonInterests: commonInterests,
                matchScore: matchScore,
              ),
            );
          } catch (e) {
            debugPrint('Error parsing user profile ${doc.id}: $e');
            continue;
          }
        }
      }

      // Sort by match score (highest first) and limit results
      matches.sort((a, b) => b.matchScore.compareTo(a.matchScore));

      final limitedMatches = matches.take(limit).toList();

      debugPrint('✅ Found ${limitedMatches.length} matches');
      for (final match in limitedMatches) {
        debugPrint(
          '🎯 Match: ${match.userProfile.displayName} - '
          '${match.distanceKm.toStringAsFixed(1)}km - '
          '${match.commonInterests.length} common interests - '
          'Score: ${match.matchScore.toStringAsFixed(2)}',
        );
        debugPrint('   Common interests: ${match.commonInterests}');
      }

      // Cache the results
      _cacheMatches(cacheKey, limitedMatches);

      return limitedMatches;
    } catch (e) {
      debugPrint('Error finding nearby matches: $e');
      return [];
    }
  }

  /// Applies the product's distance-aware compatibility rule. Thresholds stay
  /// deliberately local and tunable until product validation sets final values.
  bool _meetsDiscoverThreshold(double distanceKm, double compatibility) {
    const milesPerKilometer = 0.621371;
    final miles = distanceKm * milesPerKilometer;
    final requiredCompatibility = switch (miles) {
      < 0.1 => 0.80,
      < 0.3 => 0.85,
      < 0.5 => 0.90,
      <= 1.0 => 0.95,
      _ => 1.1,
    };
    return compatibility >= requiredCompatibility;
  }

  /// Get nearby geohashes for proximity search - OPTIMIZED
  List<String> _getNearbyGeohashes(String centerGeohash, double maxDistanceKm) {
    final geohashes = <String>{};

    // Use proper geohash precision based on distance
    int precision;
    if (maxDistanceKm <= 1) {
      precision = 6; // ~1.2km x 0.6km
    } else if (maxDistanceKm <= 5) {
      precision = 5; // ~4.9km x 4.9km
    } else if (maxDistanceKm <= 20) {
      precision = 4; // ~19.5km x 19.5km
    } else {
      precision = 3; // ~156km x 156km
    }

    // Use only the precision we need
    final baseGeohash = centerGeohash.substring(0, precision);
    geohashes.add(baseGeohash);

    // Add only immediate neighbors (8 surrounding geohashes)
    final neighbors = _getGeohashNeighbors(baseGeohash);
    geohashes.addAll(neighbors);

    // Limit to 10 geohashes (Firestore whereIn limit)
    final limitedGeohashes = geohashes.take(10).toList();

    debugPrint(
      '🔍 Generated ${limitedGeohashes.length} optimized geohashes for search (limited to 10 for Firestore)',
    );
    return limitedGeohashes;
  }

  /// Get the 8 neighboring geohashes
  List<String> _getGeohashNeighbors(String geohash) {
    // Simplified neighbor calculation - in production, use proper geohash library
    final neighbors = <String>{};
    final chars = '0123456789bcdefghjkmnpqrstuvwxyz';

    for (int i = 0; i < geohash.length; i++) {
      final char = geohash[i];
      final index = chars.indexOf(char);

      // Add variations for each position
      if (index > 0) {
        neighbors.add(
          geohash.substring(0, i) + chars[index - 1] + geohash.substring(i + 1),
        );
      }
      if (index < chars.length - 1) {
        neighbors.add(
          geohash.substring(0, i) + chars[index + 1] + geohash.substring(i + 1),
        );
      }
    }

    return neighbors.toList();
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    // Convert all coordinates to radians
    final double lat1Rad = _degreesToRadians(lat1);
    final double lat2Rad = _degreesToRadians(lat2);
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);

    // Haversine formula
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLng / 2) * sin(dLng / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// OPTIMIZED: Get common interests between two users using Set intersection
  List<String> _getCommonInterestsOptimized(
    Set<String> interests1Set,
    List<String> interests2,
  ) {
    return interests2
        .where((interest) => interests1Set.contains(interest))
        .toList();
  }

  /// Calculate category-weighted match score between two complete user profiles
  /// This is the primary matching algorithm for full profile comparisons
  /// Match score is based on:
  /// - Interest similarity (80% weight)
  /// - Vibe/personality compatibility (20% weight)
  /// Distance is used only for filtering (radius), not scoring
  /// Profile completeness affects visibility/ranking, NOT match score
  double _calculateCategoryWeightedMatchScore(
    UserProfile currentUser,
    UserProfile otherUser,
    double distanceKm,
  ) {
    // 1. Calculate category-weighted interest similarity (0-1)
    final interestScore = _calculateCategoryWeightedSimilarity(
      currentUser,
      otherUser,
    );

    // 2. Calculate vibe/personality compatibility (0-1)
    final vibeScore = VibeTags.calculateCompatibility(
      currentUser.vibeTags,
      otherUser.vibeTags,
    );

    // 3. Final score: weighted average of interest and vibe compatibility
    // Interest similarity: 80%, Vibe compatibility: 20%
    // Profile completeness is NOT included - it only affects visibility
    // This matches industry standards (Bumble, Hinge, Tinder)
    return (interestScore * 0.8) + (vibeScore * 0.2);
  }

  /// Calculate weighted Overlap Coefficient similarity per category
  /// Each category's similarity is weighted by its importance (kCategoryWeights)
  ///
  /// Uses Overlap Coefficient instead of Jaccard to reward absolute matches
  /// without penalizing users for having diverse interests.
  double _calculateCategoryWeightedSimilarity(
    UserProfile user1,
    UserProfile user2,
  ) {
    // Group interests by category for both users
    final user1Categories = user1.getInterestsByCategory();
    final user2Categories = user2.getInterestsByCategory();

    double weightedScore = 0.0;
    double totalWeight = 0.0;

    // Calculate Overlap Coefficient for each category
    for (final category in InterestCategory.values) {
      final interests1 = user1Categories[category] ?? [];
      final interests2 = user2Categories[category] ?? [];

      // Skip if neither user has interests in this category
      if (interests1.isEmpty && interests2.isEmpty) {
        continue;
      }

      // Calculate Overlap Coefficient for this category
      final categoryScore = _calculateOverlapCoefficient(
        interests1,
        interests2,
      );

      // Weight by category importance
      final categoryWeight = kCategoryWeights[category] ?? 0.0;
      weightedScore += categoryScore * categoryWeight;
      totalWeight += categoryWeight;
    }

    // Normalize by total weight to get final score (0-1)
    return totalWeight > 0 ? weightedScore / totalWeight : 0.0;
  }

  /// Calculate Overlap Coefficient between two interest lists
  /// Overlap Coefficient = |A ∩ B| / min(|A|, |B|)
  ///
  /// This is better than Jaccard for friend-finding because it:
  /// - Rewards absolute number of matches (not penalized by total interests)
  /// - Better handles asymmetric matching (users with different interest counts)
  /// - Used by industry leaders (NVIDIA, LinkedIn) for similarity matching
  ///
  /// Example:
  /// - User A: [Coding, Math, Physics, Engineering, Research, Study Buddy] (6)
  /// - User B: [Coding, Data Science, Hackathons, Reading, Languages] (5)
  /// - Common: 1 (Coding)
  /// - Jaccard = 1/10 = 0.10 (penalizes diverse interests)
  /// - Overlap = 1/5 = 0.20 (better, rewards absolute matches)
  double _calculateOverlapCoefficient(
    List<String> interests1,
    List<String> interests2,
  ) {
    if (interests1.isEmpty || interests2.isEmpty) {
      return 0.0;
    }

    final set1 = interests1.toSet();
    final set2 = interests2.toSet();

    final intersection = set1.intersection(set2).length;
    final minSize = min(set1.length, set2.length);

    return minSize > 0 ? intersection / minSize : 0.0;
  }

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
    findNearbyMatches(
          currentUserProfile,
          maxDistanceKm: maxDistanceKm,
          minCommonInterests: minCommonInterests,
          limit: limit,
        )
        .then((matches) {
          if (!controller.isClosed) controller.add(matches);
        })
        .catchError((error) {
          if (!controller.isClosed) controller.addError(error);
        });

    // Then update every 2 minutes
    final timer = Timer.periodic(const Duration(minutes: 2), (timer) {
      findNearbyMatches(
            currentUserProfile,
            maxDistanceKm: maxDistanceKm,
            minCommonInterests: minCommonInterests,
            limit: limit,
          )
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

  /// Get cached matches if they exist and are not expired
  List<ProximityMatch>? _getCachedMatches(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return null;

    if (DateTime.now().difference(timestamp) > _cacheExpiry) {
      _matchCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      return null;
    }

    return _matchCache[cacheKey];
  }

  /// Cache matches with timestamp
  void _cacheMatches(String cacheKey, List<ProximityMatch> matches) {
    _matchCache[cacheKey] = matches;
    _cacheTimestamps[cacheKey] = DateTime.now();
  }

  /// Clear all cached matches
  void clearCache() {
    _matchCache.clear();
    _cacheTimestamps.clear();
  }

  /// Force refresh matches (bypasses cache)
  Future<List<ProximityMatch>> refreshMatches(
    UserProfile currentUserProfile, {
    double? maxDistanceKm,
    int minCommonInterests = kMinCommonInterests,
    int limit = kDefaultResultLimit,
  }) async {
    // Use user's preferred search radius if not explicitly provided
    final searchRadius =
        maxDistanceKm ?? currentUserProfile.effectiveSearchRadiusKm;

    // Clear cache for this user to force fresh search
    final cacheKey =
        '${currentUserProfile.uid}_${searchRadius}_$minCommonInterests';
    _matchCache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);

    return await findNearbyMatches(
      currentUserProfile,
      maxDistanceKm: maxDistanceKm,
      minCommonInterests: minCommonInterests,
      limit: limit,
    );
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
    required this.matchScore,
  });

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
