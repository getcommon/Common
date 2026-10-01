export interface PublicDiscoverProfile {
  uid: string;
  displayName?: string | null;
  photoUrl?: string | null;
  featuredPhotoUrl?: string | null;
  photoMoments: Array<{ photoUrl: string; prompt?: string }>;
  bio?: string | null;
  interests: string[];
  vibeTags: string[];
}

interface DiscoverPayloadSource {
  displayName?: string;
  photoUrl?: string;
  featuredPhotoUrl?: string;
  photoMoments?: Array<{ photoUrl?: string; prompt?: string }>;
  bio?: string;
  interests?: string[];
  vibeTags?: string[];
}

/** Builds the deliberately small, client-visible discovery data contract. */
export function publicDiscoverProfile(
  profile: DiscoverPayloadSource,
  uid: string,
): PublicDiscoverProfile {
  const photoMoments = (profile.photoMoments ?? [])
    .filter((moment): moment is { photoUrl: string; prompt?: string } =>
      typeof moment?.photoUrl === 'string' && moment.photoUrl.length > 0,
    )
    .slice(0, 6)
    .map((moment) => ({
      photoUrl: moment.photoUrl,
      ...(typeof moment.prompt === 'string' && moment.prompt.length > 0
        ? { prompt: moment.prompt }
        : {}),
    }));

  return {
    uid,
    displayName: profile.displayName ?? null,
    photoUrl: profile.photoUrl ?? null,
    featuredPhotoUrl: profile.featuredPhotoUrl ?? null,
    photoMoments,
    bio: profile.bio ?? null,
    interests: profile.interests ?? [],
    vibeTags: profile.vibeTags ?? [],
  };
}
