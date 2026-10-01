import assert from 'node:assert/strict';
import test from 'node:test';

import {
  calculateDiscoveryScore,
  discoveryRankingVersion,
  vibeCompatibility,
  weightedJaccard,
} from './discovery_ranking';

test('weighted Jaccard gives a specific shared interest more signal than a broad one', () => {
  const broad = weightedJaccard(['Music', 'Movies'], ['Music', 'Coffee']);
  const specific = weightedJaccard(['DJing', 'Movies'], ['DJing', 'Coffee']);
  assert.ok(specific > broad);
});

test('vibe compatibility is neutral when missing and penalizes explicit conflicts', () => {
  assert.equal(vibeCompatibility([], ['night_owl']), 0.5);
  assert.equal(vibeCompatibility(['morning_person'], ['night_owl']), 0);
  assert.equal(vibeCompatibility(['morning_person'], ['morning_person']), 1);
});

test('ranking v1 remains explainable and favors shared interests at equal distance', () => {
  assert.equal(discoveryRankingVersion, 'v1');
  const stronger = calculateDiscoveryScore({
    viewerInterests: ['DJing', 'Coffee'],
    candidateInterests: ['DJing', 'Hiking'],
    distanceKm: 0.4,
  });
  const weaker = calculateDiscoveryScore({
    viewerInterests: ['DJing', 'Coffee'],
    candidateInterests: ['Music', 'Hiking'],
    distanceKm: 0.4,
  });
  assert.ok(stronger > weaker);
});
