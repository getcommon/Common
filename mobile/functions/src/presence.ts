/**
 * Presence is deliberately short lived. The client refreshes it every five
 * minutes, while matching accepts only ten minutes of freshness so a missed
 * lifecycle event cannot leave someone discoverable indefinitely.
 */
export const presenceLifetimeMs = 10 * 60 * 1000;

type TimestampValue = { toMillis: () => number } | Date | number;

export interface PresenceState {
  isVisible?: boolean;
  lastUpdated?: TimestampValue;
  expiresAt?: TimestampValue;
}

function toMillis(value: TimestampValue | undefined): number | null {
  if (typeof value === 'number') return value;
  if (value instanceof Date) return value.getTime();
  if (value && typeof value.toMillis === 'function') return value.toMillis();
  return null;
}

/** Returns true only when visibility, server freshness, and expiry all agree. */
export function hasFreshPresence(
  presence: PresenceState | undefined,
  nowMs = Date.now(),
): boolean {
  if (!presence?.isVisible) return false;
  const lastUpdatedMs = toMillis(presence.lastUpdated);
  const expiresAtMs = toMillis(presence.expiresAt);
  if (lastUpdatedMs === null || expiresAtMs === null) return false;
  return lastUpdatedMs >= nowMs - presenceLifetimeMs && expiresAtMs > nowMs;
}
