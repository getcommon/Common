import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/constants/proximity_constants.dart';
import 'package:mobile/models/user_profile.dart';

void main() {
  group('UserProfile.fromMap', () {
    test('should create profile with complete data', () {
      final map = {
        'uid': 'user1',
        'displayName': 'Alice',
        'photoUrl': 'https://example.com/photo.jpg',
        'bio': 'Hello world',
        'classYear': '2026',
        'major': 'Computer Science',
        'interests': ['Coding', 'Gaming', 'Music'],
        'vibeTags': ['Night Owl', 'Introvert'],
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'searchRadiusKm': 5.0,
      };

      final profile = UserProfile.fromMap(map);

      expect(profile.uid, 'user1');
      expect(profile.displayName, 'Alice');
      expect(profile.photoUrl, 'https://example.com/photo.jpg');
      expect(profile.bio, 'Hello world');
      expect(profile.classYear, '2026');
      expect(profile.major, 'Computer Science');
      expect(profile.interests, ['Coding', 'Gaming', 'Music']);
      expect(profile.vibeTags, ['Night Owl', 'Introvert']);
      expect(profile.searchRadiusKm, 5.0);
    });

    test('should create profile with minimal data', () {
      final map = {'uid': 'user1'};

      final profile = UserProfile.fromMap(map);

      expect(profile.uid, 'user1');
      expect(profile.displayName, isNull);
      expect(profile.photoUrl, isNull);
      expect(profile.bio, isNull);
      expect(profile.interests, isEmpty);
      expect(profile.vibeTags, isEmpty);
      expect(profile.location, isNull);
      expect(profile.searchRadiusKm, isNull);
    });

    test('should throw on missing uid', () {
      final map = {'displayName': 'Alice'};

      expect(() => UserProfile.fromMap(map), throwsArgumentError);
    });

    test('should throw on non-String uid', () {
      final map = {'uid': 123};

      expect(() => UserProfile.fromMap(map), throwsArgumentError);
    });

    test('should handle null interests list', () {
      final map = {'uid': 'user1', 'interests': null};

      final profile = UserProfile.fromMap(map);
      expect(profile.interests, isEmpty);
    });

    test('should handle null vibeTags list', () {
      final map = {'uid': 'user1', 'vibeTags': null};

      final profile = UserProfile.fromMap(map);
      expect(profile.vibeTags, isEmpty);
    });

    test('should handle null createdAt/updatedAt', () {
      final map = {'uid': 'user1', 'createdAt': null, 'updatedAt': null};

      final profile = UserProfile.fromMap(map);
      // Should default to epoch (0 milliseconds)
      expect(profile.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(profile.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('UserProfile.toMap', () {
    test('should round-trip correctly', () {
      final now = DateTime.now();
      final original = UserProfile(
        uid: 'user1',
        displayName: 'Alice',
        interests: ['Coding'],
        vibeTags: ['Night Owl'],
        createdAt: now,
        updatedAt: now,
      );

      final map = original.toMap();
      final restored = UserProfile.fromMap(map);

      expect(restored.uid, original.uid);
      expect(restored.displayName, original.displayName);
      expect(restored.interests, original.interests);
      expect(restored.vibeTags, original.vibeTags);
    });
  });

  group('UserProfile computed properties', () {
    test('isComplete should be true when interests are not empty', () {
      final profile = UserProfile(
        uid: 'user1',
        interests: ['Coding'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(profile.isComplete, true);
    });

    test('isComplete should be false when interests are empty', () {
      final profile = UserProfile(
        uid: 'user1',
        interests: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(profile.isComplete, false);
    });

    test('effectiveSearchRadiusKm should use default when null', () {
      final profile = UserProfile(
        uid: 'user1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(profile.effectiveSearchRadiusKm, isPositive);
    });

    test('effectiveSearchRadiusKm should clamp a provided value to the cap', () {
      final profile = UserProfile(
        uid: 'user1',
        searchRadiusKm: 3.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(profile.effectiveSearchRadiusKm, kMaxSearchRadiusKm);
    });
  });

  group('UserLocation.fromMap', () {
    test('should create location with all fields', () {
      final map = {
        'geohash': 'abc123',
        'latitude': 37.7749,
        'longitude': -122.4194,
        'lastUpdated': 1700000000000,
        'isVisible': true,
      };

      final location = UserLocation.fromMap(map);

      expect(location.geohash, 'abc123');
      expect(location.latitude, 37.7749);
      expect(location.longitude, -122.4194);
      expect(location.isVisible, true);
      expect(location.lastUpdated, isNotNull);
    });

    test('should throw on missing geohash', () {
      final map = {'latitude': 37.7749, 'longitude': -122.4194};

      expect(() => UserLocation.fromMap(map), throwsArgumentError);
    });

    test('should handle missing optional fields', () {
      final map = {'geohash': 'abc123'};

      final location = UserLocation.fromMap(map);

      expect(location.geohash, 'abc123');
      expect(location.latitude, isNull);
      expect(location.longitude, isNull);
      expect(location.lastUpdated, isNull);
      expect(location.isVisible, true); // default
    });

    test('should handle isVisible false', () {
      final map = {'geohash': 'abc123', 'isVisible': false};

      final location = UserLocation.fromMap(map);
      expect(location.isVisible, false);
    });
  });
}
