import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc } from 'firebase/firestore';

const rules = readFileSync('../firestore.rules', 'utf8');
let testEnv: RulesTestEnvironment;

async function seedConversation(): Promise<void> {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'conversations', 'alice_bob'), {
      participantIds: ['alice', 'bob'],
      participantProfiles: {},
      lastMessage: null,
      lastMessageTime: null,
      lastMessageSenderId: null,
      unreadCount: { alice: 0, bob: 0 },
      createdAt: new Date(),
    });
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'common-grounds-rules',
    firestore: { rules },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

test('participants cannot tamper with conversation metadata or unread counts', async () => {
  await seedConversation();
  const alice = testEnv.authenticatedContext('alice').firestore();
  const conversation = doc(alice, 'conversations', 'alice_bob');

  await assertFails(updateDoc(conversation, { lastMessage: 'forged preview' }));
  await assertFails(updateDoc(conversation, { 'unreadCount.bob': 0 }));
});

test('clients cannot write message sequence counters or messages directly', async () => {
  await seedConversation();
  const alice = testEnv.authenticatedContext('alice').firestore();

  await assertFails(
    setDoc(doc(alice, 'conversations', 'alice_bob', '_counters', 'messages'), {
      sequence: 999,
    }),
  );
  await assertFails(
    setDoc(doc(alice, 'messages', 'forged-message'), {
      conversationId: 'alice_bob',
      senderId: 'alice',
      text: 'bypass attempt',
      timestamp: new Date(),
      sequence: 1,
    }),
  );
});

test('a member can edit their own profile but cannot edit someone else’s', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', 'alice'), { uid: 'alice', bio: 'Before' });
    await setDoc(doc(db, 'users', 'bob'), { uid: 'bob', bio: 'Before' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();

  await assertSucceeds(updateDoc(doc(alice, 'users', 'alice'), { bio: 'After' }));
  await assertFails(updateDoc(doc(alice, 'users', 'bob'), { bio: 'Tampered' }));
});

test('clients cannot create a conversation without the mutual-wave callable', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(
    setDoc(doc(alice, 'conversations', 'forged'), {
      participantIds: ['alice', 'bob'],
      unreadCount: { alice: 0, bob: 0 },
    }),
  );
});
