import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:mobile/services/proximity_service.dart';
import 'package:mobile/constants/proximity_constants.dart';
import 'package:mobile/services/location_quality.dart';

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
  static const _firstFixTimeout = Duration(seconds: 12);
  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 100,
    timeLimit: _firstFixTimeout,
  );

  Timestamp _presenceExpiry() =>
      Timestamp.fromDate(DateTime.now().add(kPresenceLifetime));

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

  /// Returns a reading that is accurate enough for nearby discovery, if one
  /// can be acquired without relying on a broad network estimate.
  Future<Position?> _getUsableCurrentPosition() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          debugPrint('📍 GPS check: Location services disabled');
        }
        return null;
      }

      // Check if we have permission
      final hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        if (kDebugMode) {
          debugPrint('📍 GPS check: No location permission');
        }
        return null;
      }

      // Give iOS enough time to establish a useful first fix. Low-accuracy
      // network readings are not suitable for Common's sub-half-mile radius.
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: _locationSettings,
        );
        if (!isUsableDiscoveryLocationAccuracy(position.accuracy)) {
          if (kDebugMode) {
            debugPrint(
              '📍 GPS check: accuracy ${position.accuracy}m is too low for discovery',
            );
          }
          return null;
        }
        if (kDebugMode) {
          debugPrint('📍 GPS check: GPS is available and working');
        }
        return position;
      } catch (e) {
        // GPS request failed or timed out (likely emulator or no GPS signal)
        if (kDebugMode) {
          debugPrint('📍 GPS check: GPS not available or timed out: $e');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📍 GPS check: Error checking GPS availability: $e');
      }
      return null;
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
    final initialPosition = await _getUsableCurrentPosition();

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

    if (initialPosition != null) {
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
      await _updateUserLocation(initialPosition: initialPosition);

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
  Future<void> _updateUserLocation({Position? initialPosition}) async {
    if (_currentUserId == null) return;

    // Check if GPS is available - if so, use it even if manual override is set
    // This allows GPS to take precedence on real devices
    final measuredPosition = _useDebugOverride
        ? null
        : initialPosition ?? await _getUsableCurrentPosition();
    final gpsAvailable = measuredPosition != null;

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
        // The exact coordinate stays private to the server; medium accuracy is
        // needed to safely determine eligibility within a half-mile range.
        position = measuredPosition!;
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
          'expiresAt': _presenceExpiry(),
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
          'expiresAt': FieldValue.serverTimestamp(),
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
        'expiresAt': _presenceExpiry(),
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

  /// Lets the UI tailor recovery copy without triggering an OS prompt.
  Future<PermissionStatus> locationPermissionStatus() =>
      Permission.locationWhenInUse.status;

  /// Used only after a member chooses to recover from a permanent denial.
  Future<bool> openLocationSettings() => openAppSettings();

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
          'expiresAt': _presenceExpiry(),
          'isVisible': true,
        },
      }, SetOptions(merge: true));

      // Check if GPS is available - if not, activate manual override
      final gpsAvailable = await _getUsableCurrentPosition() != null;

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
          locationSettings: _locationSettings,
        );
        return isUsableDiscoveryLocationAccuracy(position.accuracy)
            ? position
            : null;
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
