import assert from 'node:assert/strict';
import test from 'node:test';

import { publicDiscoverProfile } from './discovery_payload';

test('discovery response includes the curated featured photo and playlist only', () => {
  const payload = publicDiscoverProfile({
    displayName: 'Kai',
    photoUrl: 'primary.jpg',
    featuredPhotoUrl: 'featured.jpg',
    photoMoments: [
      { photoUrl: 'featured.jpg', prompt: 'At the pottery studio' },
      { photoUrl: '' },
      { photoUrl: 'second.jpg' },
    ],
    interests: ['Ceramics'],
    vibeTags: ['Curious'],
    // @ts-expect-error Private location fields are intentionally not part of
    // the public discovery-payload contract.
    location: { latitude: 38.03, longitude: -78.51 },
  }, 'candidate');

  assert.equal(payload.featuredPhotoUrl, 'featured.jpg');
  assert.deepEqual(payload.photoMoments, [
    { photoUrl: 'featured.jpg', prompt: 'At the pottery studio' },
    { photoUrl: 'second.jpg' },
  ]);
  assert.equal('location' in payload, false);
});
