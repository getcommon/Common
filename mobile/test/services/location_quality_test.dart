import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/location_quality.dart';

void main() {
  group('isUsableDiscoveryLocationAccuracy', () {
    test('accepts readings precise enough for nearby discovery', () {
      expect(isUsableDiscoveryLocationAccuracy(12), isTrue);
      expect(
        isUsableDiscoveryLocationAccuracy(kMaximumDiscoveryAccuracyMeters),
        isTrue,
      );
    });

    test('rejects imprecise, invalid, and unknown readings', () {
      expect(isUsableDiscoveryLocationAccuracy(401), isFalse);
      expect(isUsableDiscoveryLocationAccuracy(-1), isFalse);
      expect(isUsableDiscoveryLocationAccuracy(double.infinity), isFalse);
      expect(isUsableDiscoveryLocationAccuracy(double.nan), isFalse);
    });
  });
}
