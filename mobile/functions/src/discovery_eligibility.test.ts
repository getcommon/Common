import assert from 'node:assert/strict';
import test from 'node:test';

import {
  discoveryEligibility,
  selectedSearchRadiusKm,
  type DiscoveryProfile,
} from './discovery_eligibility';

const now = 1_800_000_000_000;

function profile(overrides: Partial<DiscoveryProfile> = {}): DiscoveryProfile {
  return {
    interests: ['Coffee', 'Hiking'],
    searchRadiusKm: 0.8,
    location: {
      isVisible: true,
      lastUpdated: now - 60_000,
      expiresAt: now + 9 * 60_000,
      latitude: 38.03,
      longitude: -78.51,
    },
    ...overrides,
  };
}

test('accepts a fresh, nearby member with meaningful common ground', () => {
  const candidate = profile({
    location: {
      isVisible: true,
      lastUpdated: now - 60_000,
      expiresAt: now + 9 * 60_000,
      latitude: 38.0304,
      longitude: -78.51,
    },
  });

  const eligibility = discoveryEligibility(profile(), 'viewer', candidate, 'candidate', now);

  assert.ok(eligibility);
  assert.deepEqual(eligibility.commonInterests, ['Coffee', 'Hiking']);
});

test('rejects stale, out-of-radius, incompatible, and safety-excluded members', () => {
  const viewer = profile();
  assert.equal(
    discoveryEligibility(viewer, 'viewer', profile({
      location: {
        isVisible: true,
        lastUpdated: now - 11 * 60_000,
        expiresAt: now + 9 * 60_000,
        latitude: 38.0304,
        longitude: -78.51,
      },
    }), 'candidate', now),
    null,
  );
  assert.equal(
    discoveryEligibility(viewer, 'viewer', profile({
      location: {
        isVisible: true,
        lastUpdated: now,
        expiresAt: now + 9 * 60_000,
        latitude: 38.05,
        longitude: -78.51,
      },
    }), 'candidate', now),
    null,
  );
  assert.equal(
    discoveryEligibility(viewer, 'viewer', profile({ interests: ['Reading'] }), 'candidate', now),
    null,
  );
  assert.equal(
    discoveryEligibility(
      profile({ safety: { blockedUserIds: ['candidate'] } }),
      'viewer',
      profile(),
      'candidate',
      now,
    ),
    null,
  );
  assert.equal(
    discoveryEligibility(
      profile(),
      'viewer',
      profile({ safety: { unmatchedUserIds: ['viewer'] } }),
      'candidate',
      now,
    ),
    null,
  );
});

test('clamps the saved discovery radius to the supported range', () => {
  assert.equal(selectedSearchRadiusKm(profile({ searchRadiusKm: 10 })), 0.8);
  assert.equal(selectedSearchRadiusKm(profile({ searchRadiusKm: 0.01 })), 0.16);
  assert.equal(selectedSearchRadiusKm(profile({ searchRadiusKm: undefined })), 0.8);
});
