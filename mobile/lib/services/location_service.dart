import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:mobile/services/proximity_service.dart';

class LocationService {
  LocationService._();
  static final instance = LocationService._();

  final _db = FirebaseFirestore.instance;
  Timer? _locationTimer;
  String? _currentUserId;

  // When true, do not auto-update location from GPS/debug.
  // This is set when the user manually selects a location on the map.
  // Note: GPS will still take precedence if available on real devices.
  bool _manualOverrideActive = false;

  // Update interval in minutes (coarse tracking for privacy)
  static const _updateIntervalMinutes = 5;

  // Geohash precision (lower = coarser area, better privacy)
  // Precision 6 = ~1.2km x 0.6km area
  static const _geohashPrecision = 6;

  // Debug location override (disabled by default). Enable only if explicitly set.
  static bool _useDebugOverride = false;
  static const double _debugLatitude = 38.03199384346889;
  static const double _debugLongitude = -78.51068317176542;

  /// Enable or disable using the hardcoded debug coordinates.
  /// This remains OFF by default to prevent unexpected overwrites.
  void setUseDebugLocationOverride(bool enabled) {
    _useDebugOverride = enabled;
  }

  /// Check if GPS is actually available and working on the device
  Future<bool> _isGpsAvailable() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          debugPrint('📍 GPS check: Location services disabled');
        }
        return false;
      }

      // Check if we have permission
      final hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        if (kDebugMode) {
          debugPrint('📍 GPS check: No location permission');
        }
        return false;
      }

      // Try to get a position with a short timeout to verify GPS is working
      // This will fail on emulators but work on real devices
      try {
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 3), // Short timeout
          ),
        );
        if (kDebugMode) {
          debugPrint('📍 GPS check: GPS is available and working');
        }
        return true;
      } catch (e) {
        // GPS request failed or timed out (likely emulator or no GPS signal)
        if (kDebugMode) {
          debugPrint('📍 GPS check: GPS not available or timed out: $e');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📍 GPS check: Error checking GPS availability: $e');
      }
      return false;
    }
  }

  /// Initialize location tracking for a user
  Future<bool> initForUser(String uid) async {
    debugPrint('📍 LocationService: initForUser starting for uid=$uid');
    _currentUserId = uid;

    // Check and request permissions
    debugPrint('📍 LocationService: Requesting location permission...');
    final hasPermission = await _requestLocationPermission();
    if (!hasPermission) {
      debugPrint('📍 LocationService: Location permission denied');
      return false;
    }
    debugPrint('📍 LocationService: Location permission granted');

    // Check if GPS is available on this device
    debugPrint('📍 LocationService: Checking if GPS is available...');
    final gpsAvailable = await _isGpsAvailable();

    // Load existing profile location as fallback
    debugPrint('📍 LocationService: Checking for saved profile location...');
    bool hasManualLocation = false;
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data();
      final location = (data?['location'] as Map<String, dynamic>?) ?? {};
      hasManualLocation =
          location['latitude'] != null && location['longitude'] != null;
    } catch (e) {
      debugPrint('⚠️ Error reading saved location: $e');
    }

    if (gpsAvailable) {
      // GPS is available - use it and take precedence over manual location
      debugPrint('📍 LocationService: GPS available - using device location');
      _manualOverrideActive = false; // Allow GPS updates

      // Ensure location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 LocationService: Location services are disabled');
        // Fall back to manual location if available
        if (hasManualLocation) {
          _manualOverrideActive = true;
          stopTracking();
          debugPrint('📍 LocationService: Falling back to manual location');
          return true;
        }
        return false;
      }

      // Update location immediately from GPS
      debugPrint('📍 LocationService: Updating user location from GPS...');
      await _updateUserLocation();

      // Start periodic GPS updates
      debugPrint('📍 LocationService: Starting periodic GPS tracking...');
      startTracking();

      debugPrint(
        '📍 LocationService: initForUser completed successfully (GPS mode)',
      );
      return true;
    } else {
      // GPS not available - use manual location as fallback
      if (hasManualLocation) {
        debugPrint(
          '📍 LocationService: GPS not available - using manual location',
        );
        _manualOverrideActive = true;
        stopTracking();
        return true;
      } else {
        debugPrint(
          '📍 LocationService: No GPS and no manual location available',
        );
        return false;
      }
    }
  }

  /// Request location permission from user
  Future<bool> _requestLocationPermission() async {
    debugPrint('📍 LocationService: Checking current permission status...');
    var status = await Permission.locationWhenInUse.status;
    debugPrint('📍 LocationService: Current status = $status');

    if (status.isDenied) {
      debugPrint('📍 LocationService: Permission denied, requesting...');
      status = await Permission.locationWhenInUse.request();
      debugPrint('📍 LocationService: After request, status = $status');
    }

    if (status.isPermanentlyDenied) {
      debugPrint('📍 LocationService: Location permission permanently denied.');
      // Don't call openAppSettings() during startup - it can hang on emulators
      // Users can enable location later in app settings
      return false;
    }

    final result = status.isGranted || status.isLimited;
    debugPrint('📍 LocationService: Permission result = $result');
    return result;
  }

  /// Get current location and update Firestore
  Future<void> _updateUserLocation() async {
    if (_currentUserId == null) return;

    // Check if GPS is available - if so, use it even if manual override is set
    // This allows GPS to take precedence on real devices
    final gpsAvailable = await _isGpsAvailable();

    if (!gpsAvailable && _manualOverrideActive) {
      // GPS not available and manual override is active - respect manual location
      if (kDebugMode) {
        debugPrint(
          '🔒 Manual override active and GPS unavailable — skipping auto location update',
        );
      }
      return;
    }

    // If GPS is not available and we don't have manual override, don't try to get location
    // This prevents using inaccurate network-based locations (like New York default)
    if (!gpsAvailable && !_useDebugOverride) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ GPS not available — skipping location update to avoid inaccurate network location',
        );
      }
      return;
    }

    // GPS is available - use it (even if manual override was previously set)
    if (gpsAvailable && _manualOverrideActive) {
      if (kDebugMode) {
        debugPrint(
          '📍 GPS available — overriding manual location with device GPS',
        );
      }
      _manualOverrideActive =
          false; // Clear manual override since GPS is working
    }

    try {
      Position position;

      if (_useDebugOverride) {
        // Use debug coordinates for testing
        position = Position(
          latitude: _debugLatitude,
          longitude: _debugLongitude,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );

        if (kDebugMode) {
          debugPrint(
            '🔧 Using debug location: ${position.latitude}, ${position.longitude}',
          );
        }
      } else {
        // Get current position with low accuracy for privacy
        // Note: We only reach here if GPS is available (checked above)
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low, // ~1-5km accuracy for privacy
            distanceFilter: 100, // Only update if moved 100m
          ),
        );

        // Validate position accuracy to avoid using poor network-based locations
        if (position.accuracy > 50000) {
          // Accuracy worse than 50km - likely a network fallback, reject it
          if (kDebugMode) {
            debugPrint(
              '⚠️ Position accuracy too poor (${position.accuracy}m) - rejecting to avoid inaccurate location',
            );
          }
          return;
        }
      }

      // Convert to GeoFirePoint
      final geoPoint = GeoFirePoint(
        GeoPoint(position.latitude, position.longitude),
      );

      // Get geohash with specified precision (coarse for privacy)
      final geohash = geoPoint.geohash.substring(0, _geohashPrecision);

      // Update user's location in Firestore
      await _db.collection('users').doc(_currentUserId).set({
        'location': {
          'geohash': geohash,
          'geopoint': geoPoint.geopoint,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'lastUpdated': FieldValue.serverTimestamp(),
          'isVisible': true, // User can toggle this in settings
        },
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint(
          '📍 Location updated: ${position.latitude}, ${position.longitude}',
        );
        debugPrint('📍 Geohash: $geohash');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating location: $e');
      }
    }
  }

  /// Start periodic location tracking
  void startTracking() {
    // Cancel existing timer if any
    _locationTimer?.cancel();

    // Set up periodic updates
    _locationTimer = Timer.periodic(
      const Duration(minutes: _updateIntervalMinutes),
      (_) => _updateUserLocation(),
    );

    if (kDebugMode) {
      debugPrint(
        'Location tracking started (updates every $_updateIntervalMinutes minutes)',
      );
    }
  }

  /// Stop location tracking
  void stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (kDebugMode) {
      debugPrint('Location tracking stopped');
    }
  }

  /// Set user location visibility (opt-in/opt-out)
  /// Enables presence only after the member intentionally turns it on.
  /// Permission is requested here rather than during sign-in.
  Future<bool> setLocationVisibility(String uid, bool isVisible) async {
    if (!isVisible) {
      await _db.collection('users').doc(uid).set({
        'location': {
          'isVisible': false,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
      stopTracking();
      return true;
    }

    final initialized = await initForUser(uid);
    if (!initialized) return false;
    await _db.collection('users').doc(uid).set({
      'location': {
        'isVisible': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
    return true;
  }

  /// Backgrounding pauses presence; returning never resumes it automatically.
  Future<void> pauseDiscoverability(String uid) async {
    if (_currentUserId != uid) return;
    await setLocationVisibility(uid, false);
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted || status.isLimited;
  }

  /// Manually refresh location now
  Future<void> refreshLocation() async {
    await _updateUserLocation();
  }

  /// Set custom location (works in both debug and production)
  Future<void> setCustomLocation(double latitude, double longitude) async {
    if (kDebugMode) {
      debugPrint('🔧 ===== SET CUSTOM LOCATION STARTED =====');
      debugPrint('🔧 📍 Input coordinates: $latitude, $longitude');
      debugPrint('🔧 👤 Current user ID: $_currentUserId');
    }

    if (_currentUserId == null) {
      if (kDebugMode) {
        debugPrint('🔧 ❌ No current user ID - cannot set location');
        debugPrint('🔧 ===== SET CUSTOM LOCATION FAILED =====');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('🔧 🔨 Creating Position object...');
      }
      // Create a custom position
      final position = Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      if (kDebugMode) {
        debugPrint(
          '🔧 ✅ Position created: ${position.latitude}, ${position.longitude}',
        );
        debugPrint('🔧 🌍 Converting to GeoFirePoint...');
      }

      // Convert to GeoFirePoint
      final geoPoint = GeoFirePoint(
        GeoPoint(position.latitude, position.longitude),
      );

      // Get geohash with specified precision
      final geohash = geoPoint.geohash.substring(0, _geohashPrecision);

      if (kDebugMode) {
        debugPrint('🔧 ✅ GeoFirePoint created');
        debugPrint('🔧 🗺️ Geohash: $geohash');
        debugPrint('🔧 💾 Writing to Firestore...');
      }

      // Update user's location in Firestore
      await _db.collection('users').doc(_currentUserId).set({
        'location': {
          'geohash': geohash,
          'geopoint': geoPoint.geopoint,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'lastUpdated': FieldValue.serverTimestamp(),
          'isVisible': true,
        },
      }, SetOptions(merge: true));

      // Check if GPS is available - if not, activate manual override
      final gpsAvailable = await _isGpsAvailable();

      if (!gpsAvailable) {
        // GPS not available - use manual location as fallback
        _manualOverrideActive = true;
        stopTracking();
        if (kDebugMode) {
          debugPrint('🔒 GPS not available — manual location set as fallback');
        }
      } else {
        // GPS is available - it will take precedence, but save manual location too
        // Don't set manual override, allow GPS to work
        _manualOverrideActive = false;
        if (kDebugMode) {
          debugPrint(
            '📍 GPS available — manual location saved but GPS will take precedence',
          );
        }
        // Start tracking with GPS
        startTracking();
      }

      // Invalidate proximity cache so Home reflects the new location immediately
      try {
        ProximityService.instance.clearCache();
      } catch (_) {
        // Safe to ignore cache clear failures
      }

      if (kDebugMode) {
        debugPrint('🔧 ✅ Firestore write completed successfully');
        debugPrint('🔧 📍 Final coordinates saved: $latitude, $longitude');
        debugPrint('🔧 🗺️ Final geohash: $geohash');
        debugPrint('🔧 👤 User document updated: $_currentUserId');
        debugPrint('🔧 ===== SET CUSTOM LOCATION COMPLETED =====');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔧 ❌ Error setting custom location: $e');
        debugPrint('🔧 ❌ Error type: ${e.runtimeType}');
        debugPrint('🔧 ===== SET CUSTOM LOCATION FAILED =====');
      }
      rethrow; // Re-throw so the calling code can handle the error
    }
  }

  /// Get current coordinates
  Future<Position?> getCurrentCoordinates() async {
    try {
      if (_useDebugOverride) {
        // Return debug coordinates for testing
        return Position(
          latitude: _debugLatitude,
          longitude: _debugLongitude,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      } else {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            distanceFilter: 100,
          ),
        );
        return position;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting current coordinates: $e');
      }
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    stopTracking();
    _currentUserId = null;
  }
}
