import assert from 'node:assert/strict';
import test from 'node:test';
import * as admin from 'firebase-admin';

import { respondToWave, sendWave } from './index';

function callableRequest(uid: string, data: Record<string, unknown>) {
  return { auth: { uid }, data } as any;
}

async function seedEligibleProfiles(): Promise<void> {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + 9 * 60_000);
  const location = {
    latitude: 38.03199,
    longitude: -78.51068,
    geohash: 'dqb0m7',
    isVisible: true,
    lastUpdated: now,
    expiresAt,
  };
  await Promise.all([
    db.collection('users').doc('alice').set({
      uid: 'alice',
      displayName: 'Alice',
      photoUrl: 'alice.jpg',
      interests: ['Coffee'],
      location,
    }),
    db.collection('users').doc('bob').set({
      uid: 'bob',
      displayName: 'Bob',
      photoUrl: 'bob.jpg',
      interests: ['Coffee'],
      location,
    }),
  ]);
}

test('wave acceptance atomically creates reciprocal wave, match, and conversation', async () => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    'This test must run through the Firestore emulator.',
  );
  await seedEligibleProfiles();

  const sent = await sendWave.run(callableRequest('alice', { receiverId: 'bob' }));
  assert.equal(typeof sent.waveId, 'string');

  const accepted = await respondToWave.run(
    callableRequest('bob', { waveId: sent.waveId, response: 'accepted' }),
  );
  assert.equal(accepted.matchId, 'alice_bob');

  const db = admin.firestore();
  const [original, reciprocal, match, conversation] = await Promise.all([
    db.collection('waves').doc(sent.waveId).get(),
    db.collection('waves')
      .where('senderId', '==', 'bob')
      .where('receiverId', '==', 'alice')
      .get(),
    db.collection('mutual_matches').doc('alice_bob').get(),
    db.collection('conversations').doc('alice_bob').get(),
  ]);

  assert.equal(original.data()?.status, 'accepted');
  assert.equal(reciprocal.size, 1);
  assert.equal(reciprocal.docs[0].data().status, 'accepted');
  assert.equal(match.data()?.wave1Id, sent.waveId);
  assert.equal(match.data()?.wave2Id, reciprocal.docs[0].id);
  assert.deepEqual(conversation.data()?.participantIds, ['alice', 'bob']);
  assert.deepEqual(conversation.data()?.unreadCount, { alice: 0, bob: 0 });
});
