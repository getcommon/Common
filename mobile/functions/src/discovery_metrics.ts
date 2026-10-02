import * as admin from 'firebase-admin';

/**
 * Privacy-preserving Discovery telemetry. These are daily, sharded counters:
 * no member IDs, coordinates, names, or profile fields are written here.
 *
 * Shards avoid a single hot document as Discover refreshes grow. A reporting
 * job can sum the shards for a date and ranking version.
 */
const metricShardCount = 20;

export type DiscoveryMetric =
  | 'discoveryRequests'
  | 'profilesShown'
  | 'wavesSent'
  | 'mutualMatches'
  | 'hides'
  | 'unmatches'
  | 'blocks';

function metricDate(now: Date): string {
  return now.toISOString().slice(0, 10);
}

export function metricDocumentId(
  rankingVersion: string,
  now: Date = new Date(),
): string {
  // Ranking versions are product-controlled strings, but keeping the ID
  // conservative makes its document contract explicit.
  const safeVersion = rankingVersion.replace(/[^a-zA-Z0-9_-]/g, '_');
  return `${metricDate(now)}_${safeVersion}`;
}

/** Adds counters to one random shard. Values must be positive integers. */
export async function recordDiscoveryMetrics(
  metrics: Partial<Record<DiscoveryMetric, number>>,
  rankingVersion: string,
  db: FirebaseFirestore.Firestore = admin.firestore(),
): Promise<void> {
  const increments = Object.entries(metrics).filter(
    ([, value]) => Number.isInteger(value) && (value ?? 0) > 0,
  ) as Array<[DiscoveryMetric, number]>;
  if (increments.length === 0) return;

  const metricId = metricDocumentId(rankingVersion);
  const shard = Math.floor(Math.random() * metricShardCount);
  const ref = db.collection('discovery_metrics').doc(metricId)
    .collection('shards').doc(String(shard));
  await ref.set({
    date: metricId.slice(0, 10),
    rankingVersion,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...Object.fromEntries(
      increments.map(([metric, value]) => [metric, admin.firestore.FieldValue.increment(value)]),
    ),
  }, { merge: true });
}

/** True only for an actual newly-added item, not an existing safety setting. */
export function hasNewSafetyEntry(before: unknown, after: unknown): boolean {
  const beforeValues = new Set(Array.isArray(before) ? before.filter((value) => typeof value === 'string') : []);
  return Array.isArray(after) && after.some(
    (value) => typeof value === 'string' && !beforeValues.has(value),
  );
}
