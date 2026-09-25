/// Location readings beyond this accuracy cannot reliably support Common's
/// sub-half-mile discovery range. The value is deliberately less than that
/// range, leaving margin for both members' uncertainty.
const double kMaximumDiscoveryAccuracyMeters = 400;

/// Returns whether a device location is sufficiently precise for discovery.
bool isUsableDiscoveryLocationAccuracy(double accuracyMeters) =>
    accuracyMeters.isFinite &&
    accuracyMeters >= 0 &&
    accuracyMeters <= kMaximumDiscoveryAccuracyMeters;
