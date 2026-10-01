import { geohashQueryBounds } from 'geofire-common';

export type GeohashRange = readonly [start: string, end: string];

/**
 * Produces lexicographic geohash ranges that cover a circle. The ranges are
 * deliberately a broad candidate stage: exact distance is still enforced by
 * discoveryEligibility before a profile can be returned.
 */
export function geohashRangesForRadius(
  latitude: number,
  longitude: number,
  radiusKm: number,
): GeohashRange[] {
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
      !Number.isFinite(longitude) || longitude < -180 || longitude > 180 ||
      !Number.isFinite(radiusKm) || radiusKm <= 0) {
    throw new RangeError('A valid coordinate and positive radius are required.');
  }

  // geofire-common uses metres, while product settings use kilometres.
  return geohashQueryBounds([latitude, longitude], radiusKm * 1000)
    .map(([start, end]) => [start, end] as const);
}

export function geohashIsCoveredByRanges(
  geohash: string,
  ranges: readonly GeohashRange[],
): boolean {
  return ranges.some(([start, end]) => geohash >= start && geohash <= end);
}
