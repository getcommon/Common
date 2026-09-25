import { hasFreshPresence, type PresenceState } from './presence';

export const defaultSearchRadiusKm = 0.8;
export const minSearchRadiusKm = 0.16;
export const maxSearchRadiusKm = 0.8;
export const minCommonInterests = 1;

export interface DiscoveryLocation extends PresenceState {
  latitude?: number;
  longitude?: number;
}

export interface DiscoverySafety {
  blockedUserIds?: string[];
  unmatchedUserIds?: string[];
}

export interface DiscoveryProfile {
  interests?: string[];
  location?: DiscoveryLocation;
  searchRadiusKm?: number;
  safety?: DiscoverySafety;
}

export interface DiscoveryEligibility {
  distanceKm: number;
  commonInterests: string[];
  matchScore: number;
}

export function selectedSearchRadiusKm(profile: DiscoveryProfile): number {
  const requestedRadius = profile.searchRadiusKm;
  if (typeof requestedRadius !== 'number' || !Number.isFinite(requestedRadius)) {
    return defaultSearchRadiusKm;
  }
  return Math.min(Math.max(requestedRadius, minSearchRadiusKm), maxSearchRadiusKm);
}

export function excludesMember(profile: DiscoveryProfile, otherUserId: string): boolean {
  const safety = profile.safety;
  return safety?.blockedUserIds?.includes(otherUserId) === true ||
    safety?.unmatchedUserIds?.includes(otherUserId) === true;
}

function hasCoordinates(location: DiscoveryLocation | undefined): location is DiscoveryLocation & {
  latitude: number;
  longitude: number;
} {
  return Number.isFinite(location?.latitude) && Number.isFinite(location?.longitude);
}

export function calculateDistanceKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const earthRadiusKm = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) *
      Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return 2 * earthRadiusKm * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function commonInterests(first: string[], second: string[]): string[] {
  const firstInterests = new Set(first);
  return second.filter((interest) => firstInterests.has(interest));
}

export function calculateMatchScore(
  sharedInterestCount: number,
  firstInterestCount: number,
  secondInterestCount: number,
  distanceKm: number,
): number {
  const interestSimilarity = sharedInterestCount /
    (firstInterestCount + secondInterestCount - sharedInterestCount);
  const distanceScore = (10 - Math.min(distanceKm, 10)) / 10;
  return interestSimilarity * 0.7 + distanceScore * 0.3;
}

export function meetsDistanceAwareThreshold(distanceKm: number, matchScore: number): boolean {
  const miles = distanceKm * 0.621371;
  const requiredScore = miles < 0.1
    ? 0.80
    : miles < 0.3
    ? 0.85
    : miles <= 0.5
    ? 0.90
    : 1.1;
  return matchScore >= requiredScore;
}

/**
 * Returns the server-authoritative discovery facts when `candidate` may be
 * shown to, and waved by, `viewer`; otherwise returns null.
 */
export function discoveryEligibility(
  viewer: DiscoveryProfile,
  viewerId: string,
  candidate: DiscoveryProfile,
  candidateId: string,
  nowMs = Date.now(),
): DiscoveryEligibility | null {
  const viewerLocation = viewer.location;
  const candidateLocation = candidate.location;
  const viewerInterests = viewer.interests ?? [];
  const candidateInterests = candidate.interests ?? [];

  if (!hasFreshPresence(viewerLocation, nowMs) || !hasFreshPresence(candidateLocation, nowMs) ||
      !hasCoordinates(viewerLocation) || !hasCoordinates(candidateLocation) ||
      viewerInterests.length === 0 || candidateInterests.length === 0 ||
      excludesMember(viewer, candidateId) || excludesMember(candidate, viewerId)) {
    return null;
  }

  const distanceKm = calculateDistanceKm(
    viewerLocation.latitude,
    viewerLocation.longitude,
    candidateLocation.latitude,
    candidateLocation.longitude,
  );
  if (distanceKm > selectedSearchRadiusKm(viewer)) return null;

  const sharedInterests = commonInterests(viewerInterests, candidateInterests);
  if (sharedInterests.length < minCommonInterests) return null;

  const matchScore = calculateMatchScore(
    sharedInterests.length,
    viewerInterests.length,
    candidateInterests.length,
    distanceKm,
  );
  if (!meetsDistanceAwareThreshold(distanceKm, matchScore)) return null;

  return { distanceKm, commonInterests: sharedInterests, matchScore };
}
