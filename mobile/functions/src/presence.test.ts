import assert from 'node:assert/strict';
import test from 'node:test';

import { hasFreshPresence, presenceLifetimeMs } from './presence';

const now = 1_800_000_000_000;

test('accepts visible, recently refreshed presence that has not expired', () => {
  assert.equal(
    hasFreshPresence({
      isVisible: true,
      lastUpdated: now - 5 * 60 * 1000,
      expiresAt: now + 5 * 60 * 1000,
    }, now),
    true,
  );
});

test('rejects hidden, expired, or stale presence', () => {
  assert.equal(hasFreshPresence({ isVisible: false }, now), false);
  assert.equal(
    hasFreshPresence({
      isVisible: true,
      lastUpdated: now,
      expiresAt: now,
    }, now),
    false,
  );
  assert.equal(
    hasFreshPresence({
      isVisible: true,
      lastUpdated: now - presenceLifetimeMs - 1,
      expiresAt: now + 1,
    }, now),
    false,
  );
});
