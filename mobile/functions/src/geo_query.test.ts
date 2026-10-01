import assert from 'node:assert/strict';
import test from 'node:test';
import { geohashForLocation } from 'geofire-common';

import { geohashIsCoveredByRanges, geohashRangesForRadius } from './geo_query';

test('candidate ranges include a nearby member across a six-character geohash boundary', () => {
  const viewer: [number, number] = [38.03199384346889, -78.51068317176542];
  // Roughly 0.5 km east of the viewer: intentionally close enough to fall in
  // the selected 0.8 km radius, but likely to occupy a different prefix cell.
  const nearbyCandidate: [number, number] = [38.03199384346889, -78.5046];
  const ranges = geohashRangesForRadius(viewer[0], viewer[1], 0.8);
  const viewerHash = geohashForLocation(viewer).slice(0, 6);
  const candidateHash = geohashForLocation(nearbyCandidate).slice(0, 6);

  assert.ok(ranges.length > 1);
  assert.notEqual(candidateHash, viewerHash);
  assert.equal(geohashIsCoveredByRanges(candidateHash, ranges), true);
});

test('invalid geo-query inputs fail closed', () => {
  assert.throws(() => geohashRangesForRadius(91, 0, 0.8), RangeError);
  assert.throws(() => geohashRangesForRadius(0, 0, 0), RangeError);
});
