/**
 * Server-only, explainable Discovery ranking. Keep this versioned so later
 * experiments can be compared without changing the Flutter contract.
 */
export const discoveryRankingVersion = 'v1';

// These are deliberately small, product-owned adjustments—not claims about
// population frequency. Aggregate interaction data can replace them later.
const broadInterestWeights: Record<string, number> = {
  Coffee: 0.75,
  Foodie: 0.8,
  Gaming: 0.8,
  Gym: 0.8,
  Movies: 0.8,
  Music: 0.8,
  Reading: 0.85,
  Travel: 0.85,
};

const specificInterestWeights: Record<string, number> = {
  'Board Games': 1.15,
  'Data Science': 1.2,
  DJing: 1.2,
  Hackathons: 1.15,
  'Rock Climbing': 1.15,
  Poetry: 1.15,
};

const conflictingVibes: Record<string, readonly string[]> = {
  extrovert: ['introvert'],
  introvert: ['extrovert'],
  morning_person: ['night_owl'],
  night_owl: ['morning_person'],
  high_energy: ['chill'],
  chill: ['high_energy'],
  music_on: ['silence'],
  silence: ['music_on'],
};

export function interestSpecificityWeight(interest: string): number {
  return specificInterestWeights[interest] ?? broadInterestWeights[interest] ?? 1;
}

export function weightedJaccard(first: readonly string[], second: readonly string[]): number {
  const firstSet = new Set(first);
  const secondSet = new Set(second);
  const union = new Set([...firstSet, ...secondSet]);
  if (union.size === 0) return 0;

  let intersectionWeight = 0;
  let unionWeight = 0;
  for (const interest of union) {
    const weight = interestSpecificityWeight(interest);
    unionWeight += weight;
    if (firstSet.has(interest) && secondSet.has(interest)) {
      intersectionWeight += weight;
    }
  }
  return intersectionWeight / unionWeight;
}

export function vibeCompatibility(first: readonly string[], second: readonly string[]): number {
  if (first.length === 0 || second.length === 0) return 0.5;
  const scores = first.map((tag) => {
    if (second.includes(tag)) return 1;
    if (second.some((other) => conflictingVibes[tag]?.includes(other))) return 0;
    return 0.5;
  });
  return scores.reduce((sum, score) => sum + score, 0) / scores.length;
}

export interface DiscoveryRankingInput {
  viewerInterests: readonly string[];
  candidateInterests: readonly string[];
  viewerVibeTags?: readonly string[];
  candidateVibeTags?: readonly string[];
  distanceKm: number;
}

export function calculateDiscoveryScore(input: DiscoveryRankingInput): number {
  const interestScore = weightedJaccard(input.viewerInterests, input.candidateInterests);
  // The product radius is under one kilometre; retaining a ten-kilometre
  // normalization preserves the existing gentle distance contribution.
  const distanceScore = (10 - Math.min(input.distanceKm, 10)) / 10;
  const vibes = vibeCompatibility(input.viewerVibeTags ?? [], input.candidateVibeTags ?? []);
  return (interestScore * 0.65) + (distanceScore * 0.25) + (vibes * 0.1);
}
