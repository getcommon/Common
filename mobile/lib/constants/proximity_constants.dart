/// Proximity search configuration constants
/// Following industry best practices for location-based social apps
library;

/// Minimum search radius in kilometers
/// Covers the closest block or building.
const double kMinSearchRadiusKm = 0.16;

/// Default search radius in kilometers
/// Product's initial preferred public discovery radius: under 0.5 miles.
const double kDefaultSearchRadiusKm = 0.8;

/// Maximum search radius in kilometers
/// One mile remains an experiment for later; version one stops at 0.5 miles.
const double kMaxSearchRadiusKm = 0.8;

/// Minimum number of common interests required for a match
const int kMinCommonInterests = 1;

/// Default result limit for proximity searches
const int kDefaultResultLimit = 10;

/// Cache expiry duration for proximity matches
const Duration kMatchCacheExpiry = Duration(minutes: 5);

/// Helper to clamp radius within valid bounds
double clampSearchRadius(double radius) {
  return radius.clamp(kMinSearchRadiusKm, kMaxSearchRadiusKm);
}

/// Format radius for display (shows meters if < 1km)
String formatRadius(double radiusKm) {
  if (radiusKm < 1.0) {
    return '${(radiusKm * 1000).round()}m';
  }
  return '${radiusKm.toStringAsFixed(1)}km';
}
