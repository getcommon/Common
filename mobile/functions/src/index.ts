import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { hasFreshPresence } from './presence';
import {
  discoveryEligibility,
  selectedSearchRadiusKm,
} from './discovery_eligibility';
import { geohashRangesForRadius } from './geo_query';
import { publicDiscoverProfile, type PublicDiscoverProfile } from './discovery_payload';
import { discoveryRankingVersion } from './discovery_ranking';
import { moderationRejection } from './content_moderation';
import { hasNewSafetyEntry, recordDiscoveryMetrics } from './discovery_metrics';

// Initialize Firebase Admin
admin.initializeApp();

// Set global options for 2nd gen functions
setGlobalOptions({
  region: 'us-central1',
});

// Types for our data structures
interface UserLocation {
  geohash: string;
  latitude: number;
  longitude: number;
  lastUpdated: admin.firestore.Timestamp;
  expiresAt: admin.firestore.Timestamp;
  isVisible: boolean;
}

interface UserProfile {
  uid: string;
  displayName?: string;
  photoUrl?: string;
  featuredPhotoUrl?: string;
  photoMoments?: Array<{ photoUrl?: string; prompt?: string }>;
  bio?: string;
  classYear?: string;
  major?: string;
  interests: string[];
  topInterests?: string[];
  vibeTags?: string[];
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
  location?: UserLocation;
  searchRadiusKm?: number;
  safety?: {
    blockedUserIds?: string[];
    unmatchedUserIds?: string[];
  };
}

interface ProximityMatch {
  userProfile: PublicDiscoverProfile;
  distanceKm: number;
  commonInterests: string[];
  topSharedInterests: string[];
  matchScore: number;
}

interface FindMatchesResponse {
  matches: ProximityMatch[];
  rankingVersion: string;
  totalProcessed: number;
  executionTimeMs: number;
}

const dailyWaveLimit = 3;
const batchDeleteLimit = 400;

async function deleteQuery(query: FirebaseFirestore.Query): Promise<void> {
  const db = admin.firestore();
  while (true) {
    const snapshot = await query.limit(batchDeleteLimit).get();
    if (snapshot.empty) return;

    const batch = db.batch();
    for (const document of snapshot.docs) {
      batch.delete(document.ref);
    }
    await batch.commit();
  }
}

async function deleteConversation(conversationId: string): Promise<void> {
  const db = admin.firestore();
  await deleteQuery(
    db.collection('messages').where('conversationId', '==', conversationId),
  );
  await deleteQuery(db.collection('conversations').doc(conversationId).collection('_counters'));
  await db.collection('conversations').doc(conversationId).delete();
}

function connectionId(firstUserId: string, secondUserId: string): string {
  return [firstUserId, secondUserId].sort().join('_');
}

function profilePreview(profile: FirebaseFirestore.DocumentData) {
  return {
    displayName: profile.displayName ?? null,
    photoUrl: profile.photoUrl ?? null,
  };
}

/** Measurement is useful, but must never change a member-facing outcome. */
async function recordMetricsBestEffort(
  metrics: Parameters<typeof recordDiscoveryMetrics>[0],
  db?: FirebaseFirestore.Firestore,
): Promise<void> {
  try {
    await recordDiscoveryMetrics(metrics, discoveryRankingVersion, db);
  } catch (error) {
    console.error('Unable to record discovery metrics:', error);
  }
}

/**
 * Creates a wave only after checking the daily allowance and existing state on
 * the server. Client supplied profile metadata is intentionally ignored.
 */
export const sendWave = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to send a wave.');
  }
  const receiverId = request.data?.receiverId;
  if (typeof receiverId !== 'string' || !receiverId || receiverId === request.auth.uid) {
    throw new HttpsError('invalid-argument', 'Choose another member to wave to.');
  }

  const db = admin.firestore();
  const senderId = request.auth.uid;
  const today = admin.firestore.Timestamp.fromDate(
    new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate()),
  );
  const waveRef = db.collection('waves').doc();

  await db.runTransaction(async (transaction) => {
    const [sender, receiver, todayWaves, existing] = await Promise.all([
      transaction.get(db.collection('users').doc(senderId)),
      transaction.get(db.collection('users').doc(receiverId)),
      transaction.get(
        db.collection('waves')
          .where('senderId', '==', senderId)
          .where('timestamp', '>=', today),
      ),
      transaction.get(
        db.collection('waves')
          .where('senderId', '==', senderId)
          .where('receiverId', '==', receiverId)
          .limit(1),
      ),
    ]);
    if (!sender.exists || !receiver.exists) {
      throw new HttpsError('not-found', 'That profile is no longer available.');
    }
    const senderProfile = sender.data() as UserProfile;
    const receiverProfile = receiver.data() as UserProfile;
    if (!discoveryEligibility(senderProfile, senderId, receiverProfile, receiverId)) {
      throw new HttpsError(
        'failed-precondition',
        'This member is no longer eligible for discovery.',
      );
    }
    if (todayWaves.size >= dailyWaveLimit) {
      throw new HttpsError('resource-exhausted', 'Today’s waves have been used.');
    }
    if (!existing.empty) {
      throw new HttpsError('already-exists', 'A wave already exists.');
    }
    transaction.set(waveRef, {
      senderId,
      receiverId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'pending',
      respondedAt: null,
      senderProfile: profilePreview(senderProfile),
      receiverProfile: profilePreview(receiverProfile),
    });
  });

  // A daily aggregate only—never the sender, recipient, or their location.
  await recordMetricsBestEffort({ wavesSent: 1 }, db);

  return { waveId: waveRef.id };
});

/**
 * Responds to a received wave and, when accepted, creates the reciprocal wave,
 * mutual connection, and conversation in one server-authoritative transaction.
 */
export const respondToWave = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to respond to a wave.');
  }
  const waveId = request.data?.waveId;
  const response = request.data?.response;
  if (typeof waveId !== 'string' || !['accepted', 'declined'].includes(response)) {
    throw new HttpsError('invalid-argument', 'A wave and valid response are required.');
  }

  const db = admin.firestore();
  const waveRef = db.collection('waves').doc(waveId);
  let matchId: string | null = null;
  let createdMatch = false;
  await db.runTransaction(async (transaction) => {
    const waveSnapshot = await transaction.get(waveRef);
    if (!waveSnapshot.exists) throw new HttpsError('not-found', 'Wave not found.');
    const wave = waveSnapshot.data()!;
    if (wave.receiverId !== request.auth!.uid || wave.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'That wave is no longer available.');
    }
    if (response === 'declined') {
      transaction.update(waveRef, {
        status: response,
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const reverseRef = db.collection('waves').doc();
    const id = connectionId(wave.senderId, wave.receiverId);
    const matchRef = db.collection('mutual_matches').doc(id);
    const conversationRef = db.collection('conversations').doc(id);
    const [existingReverse, existingMatch, existingConversation] = await Promise.all([
      transaction.get(
        db.collection('waves')
          .where('senderId', '==', wave.receiverId)
          .where('receiverId', '==', wave.senderId)
          .limit(1),
      ),
      transaction.get(matchRef),
      transaction.get(conversationRef),
    ]);
    const reverseWaveId = existingReverse.empty ? reverseRef.id : existingReverse.docs[0].id;
    // Firestore transactions require every read above to complete before this
    // first write. Keep the accepted-wave transition in the same atomic commit.
    transaction.update(waveRef, {
      status: response,
      respondedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (existingReverse.empty) {
      transaction.set(reverseRef, {
        senderId: wave.receiverId,
        receiverId: wave.senderId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'accepted',
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
        senderProfile: wave.receiverProfile,
        receiverProfile: wave.senderProfile,
      });
    } else if (existingReverse.docs[0].data().status === 'pending') {
      transaction.update(existingReverse.docs[0].ref, {
        status: 'accepted',
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    if (!existingMatch.exists) {
      createdMatch = true;
      transaction.set(matchRef, {
        user1Id: wave.senderId,
        user2Id: wave.receiverId,
        matchedAt: admin.firestore.FieldValue.serverTimestamp(),
        wave1Id: waveRef.id,
        wave2Id: reverseWaveId,
        user1Profile: wave.senderProfile,
        user2Profile: wave.receiverProfile,
      });
    }
    if (!existingConversation.exists) {
      transaction.set(conversationRef, {
        participantIds: [wave.senderId, wave.receiverId],
        participantProfiles: {
          [wave.senderId]: wave.senderProfile,
          [wave.receiverId]: wave.receiverProfile,
        },
        lastMessage: null,
        lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageSenderId: null,
        unreadCount: { [wave.senderId]: 0, [wave.receiverId]: 0 },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    matchId = id;
  });
  if (createdMatch) {
    await recordMetricsBestEffort({ mutualMatches: 1 }, db);
  }
  return { matchId };
});

/** Cancels only the caller's own pending outgoing wave. */
export const cancelWave = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to cancel a wave.');
  const waveId = request.data?.waveId;
  if (typeof waveId !== 'string' || !waveId) {
    throw new HttpsError('invalid-argument', 'A wave is required.');
  }

  const waveRef = admin.firestore().collection('waves').doc(waveId);
  await admin.firestore().runTransaction(async (transaction) => {
    const wave = await transaction.get(waveRef);
    if (!wave.exists) throw new HttpsError('not-found', 'Wave not found.');
    const data = wave.data()!;
    if (data.senderId !== request.auth!.uid || data.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'That wave can no longer be cancelled.');
    }
    transaction.delete(waveRef);
  });
  return { cancelled: true };
});

/** Marks a participant's conversation view read without granting broad writes. */
export const markConversationRead = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to update a conversation.');
  const conversationId = request.data?.conversationId;
  if (typeof conversationId !== 'string' || !conversationId) {
    throw new HttpsError('invalid-argument', 'A conversation is required.');
  }

  const conversationRef = admin.firestore().collection('conversations').doc(conversationId);
  await admin.firestore().runTransaction(async (transaction) => {
    const conversation = await transaction.get(conversationRef);
    if (!conversation.exists || !conversation.data()?.participantIds?.includes(request.auth!.uid)) {
      throw new HttpsError('permission-denied', 'You are not part of this conversation.');
    }
    transaction.update(conversationRef, {
      [`unreadCount.${request.auth!.uid}`]: 0,
      [`lastViewed.${request.auth!.uid}`]: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  return { markedRead: true };
});

/** Removes a conversation only after verifying the caller is a participant. */
export const removeConversation = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to remove a conversation.');
  const conversationId = request.data?.conversationId;
  if (typeof conversationId !== 'string' || !conversationId) {
    throw new HttpsError('invalid-argument', 'A conversation is required.');
  }
  const conversation = await admin.firestore().collection('conversations').doc(conversationId).get();
  if (!conversation.exists || !conversation.data()?.participantIds?.includes(request.auth.uid)) {
    throw new HttpsError('permission-denied', 'You are not part of this conversation.');
  }
  await deleteConversation(conversationId);
  return { removed: true };
});

/**
 * Creates a moderation case from a member report. The client never gets read
 * access to reports; trusted moderators review `reports` in Firebase Admin.
 */
export const submitReport = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to submit a report.');
  }
  const subjectId = request.data?.subjectId;
  const reason = request.data?.reason;
  const conversationId = request.data?.conversationId;
  if (typeof subjectId !== 'string' || !subjectId || subjectId === request.auth.uid ||
      typeof reason !== 'string' || !reason.trim()) {
    throw new HttpsError('invalid-argument', 'A member and report reason are required.');
  }
  if (conversationId != null && (typeof conversationId !== 'string' || !conversationId)) {
    throw new HttpsError('invalid-argument', 'The conversation reference is invalid.');
  }

  const db = admin.firestore();
  const [subject, conversation] = await Promise.all([
    db.collection('users').doc(subjectId).get(),
    conversationId ? db.collection('conversations').doc(conversationId).get() : null,
  ]);
  if (!subject.exists) {
    throw new HttpsError('not-found', 'That member is no longer available.');
  }
  if (conversationId && (!conversation?.exists ||
      !Array.isArray(conversation.data()?.participantIds) ||
      !conversation.data()!.participantIds.includes(request.auth.uid) ||
      !conversation.data()!.participantIds.includes(subjectId))) {
    throw new HttpsError('permission-denied', 'You can report only members in your conversation.');
  }

  const report = await db.collection('reports').add({
    reporterId: request.auth.uid,
    subjectId,
    reason: reason.trim().slice(0, 500),
    conversationId: conversationId ?? null,
    status: 'open',
    reviewedAt: null,
    resolution: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { reportId: report.id };
});

/**
 * Stores a chat message only after enforcing participant access and the
 * server-side safety screen. Direct client writes are denied by Firestore
 * rules, so this boundary cannot be bypassed from a modified app.
 */
export const sendMessage = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to send a message.');
  }
  const conversationId = request.data?.conversationId;
  const text = request.data?.text;
  if (typeof conversationId !== 'string' || !conversationId ||
      typeof text !== 'string' || !text.trim() || text.trim().length > 1000) {
    throw new HttpsError('invalid-argument', 'Send a message between 1 and 1,000 characters.');
  }
  const rejection = moderationRejection(text.trim());
  if (rejection) {
    throw new HttpsError('failed-precondition', rejection);
  }

  const db = admin.firestore();
  const conversationRef = db.collection('conversations').doc(conversationId);
  const counterRef = conversationRef.collection('_counters').doc('messages');
  const messageRef = db.collection('messages').doc();
  await db.runTransaction(async (transaction) => {
    const [conversation, counter] = await Promise.all([
      transaction.get(conversationRef),
      transaction.get(counterRef),
    ]);
    if (!conversation.exists || !conversation.data()?.participantIds?.includes(request.auth!.uid)) {
      throw new HttpsError('permission-denied', 'You are not part of this conversation.');
    }
    const sequence = (counter.data()?.sequence ?? 0) + 1;
    const unreadCount = { ...(conversation.data()?.unreadCount ?? {}) };
    for (const participantId of conversation.data()!.participantIds) {
      if (participantId !== request.auth!.uid) {
        unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1;
      }
    }
    transaction.set(counterRef, { sequence }, { merge: true });
    transaction.set(messageRef, {
      conversationId,
      senderId: request.auth!.uid,
      text: text.trim(),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      sequence,
      isRead: false,
    });
    transaction.update(conversationRef, {
      lastMessage: text.trim(),
      lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageSenderId: request.auth!.uid,
      unreadCount,
    });
  });
  return { messageId: messageRef.id };
});

/**
 * Permanently removes a member's account and the product data associated with
 * it. This is intentionally server-side so clients cannot leave orphaned
 * conversations, messages, or Firebase Authentication identities behind.
 */
export const deleteUserAccount = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to delete your account.');
  }
  if (request.data?.confirm !== true) {
    throw new HttpsError('failed-precondition', 'Confirm account deletion before continuing.');
  }

  const db = admin.firestore();
  const userId = request.auth.uid;
  const conversations = await db
    .collection('conversations')
    .where('participantIds', 'array-contains', userId)
    .get();

  await Promise.all(conversations.docs.map((conversation) => deleteConversation(conversation.id)));
  await Promise.all([
    deleteQuery(db.collection('messages').where('senderId', '==', userId)),
    deleteQuery(db.collection('waves').where('senderId', '==', userId)),
    deleteQuery(db.collection('waves').where('receiverId', '==', userId)),
    deleteQuery(db.collection('mutual_matches').where('user1Id', '==', userId)),
    deleteQuery(db.collection('mutual_matches').where('user2Id', '==', userId)),
    deleteQuery(db.collection('reports').where('reporterId', '==', userId)),
    deleteQuery(db.collection('reports').where('subjectId', '==', userId)),
  ]);
  await db.collection('users').doc(userId).delete();

  try {
    await admin.storage().bucket().file(`profile_pictures/${userId}/primary.jpg`).delete();
  } catch (error: any) {
    if (error?.code !== 404) throw error;
  }
  const [playlistFiles] = await admin.storage().bucket().getFiles({
    prefix: `profile_playlists/${userId}/`,
  });
  await Promise.all(playlistFiles.map((file) => file.delete()));
  await admin.auth().deleteUser(userId);
  return { deleted: true };
});

const candidateLimitPerGeoRange = 250;
const candidatePoolLimit = 500;

/**
 * Cloud Function to find nearby users with similar interests
 */
export const findNearbyMatches = onCall(
  { region: 'us-central1' },
  async (request): Promise<FindMatchesResponse> => {
    const context = request.auth;
    const startTime = Date.now();
    
    // Validate authentication
    if (!context) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated to find matches'
      );
    }

    const currentUserUid = context.uid;
    // Radius is always the member's own selected setting, capped to the
    // product's preferred 0.5-mile range. The caller cannot widen it.
    const limit = 10;

    try {
      const db = admin.firestore();
      
      // Get current user profile
      const currentUserDoc = await db.collection('users').doc(currentUserUid).get();
      if (!currentUserDoc.exists) {
        throw new HttpsError(
          'not-found',
          'Current user profile not found'
        );
      }

      const currentUserProfile = currentUserDoc.data() as UserProfile;
      const selectedRadiusKm = selectedSearchRadiusKm(currentUserProfile);
      
      // Validate user has location and interests
      if (!hasFreshPresence(currentUserProfile.location)) {
        return {
          matches: [],
          rankingVersion: discoveryRankingVersion,
          totalProcessed: 0,
          executionTimeMs: Date.now() - startTime
        };
      }

      if (currentUserProfile.interests.length === 0) {
        return {
          matches: [],
          rankingVersion: discoveryRankingVersion,
          totalProcessed: 0,
          executionTimeMs: Date.now() - startTime
        };
      }

      const currentLat = currentUserProfile.location.latitude;
      const currentLng = currentUserProfile.location.longitude;

      if (!Number.isFinite(currentLat) || !Number.isFinite(currentLng) ||
          currentLat < -90 || currentLat > 90 || currentLng < -180 || currentLng > 180) {
        throw new HttpsError(
          'invalid-argument',
          'Current user location coordinates not available'
        );
      }

      // These vetted-library bounds cover every geohash cell that intersects
      // the search circle. They are only candidate retrieval; the exact
      // Haversine boundary remains enforced below by discoveryEligibility.
      const geohashRanges = geohashRangesForRadius(
        currentLat,
        currentLng,
        selectedRadiusKm,
      );

      console.log(`🔍 PROXIMITY SEARCH STARTED for user: ${currentUserProfile.displayName}`);
      console.log(`🔍 Searching ${geohashRanges.length} geospatial candidate ranges`);

      const rangeSnapshots = await Promise.all(geohashRanges.map(([start, end]) =>
        db.collection('users')
          .where('location.isVisible', '==', true)
          .orderBy('location.geohash')
          .startAt(start)
          .endAt(end)
          .limit(candidateLimitPerGeoRange)
          .get(),
      ));
      const candidates = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
      for (const snapshot of rangeSnapshots) {
        for (const document of snapshot.docs) candidates.set(document.id, document);
      }
      // When a dense area exceeds the bounded pool, favor recently refreshed
      // presence rather than incidental document/lexicographic order.
      const candidateDocuments = [...candidates.values()]
        .sort((first, second) => {
          const firstUpdated = (first.data().location?.lastUpdated as admin.firestore.Timestamp | undefined)
            ?.toMillis() ?? 0;
          const secondUpdated = (second.data().location?.lastUpdated as admin.firestore.Timestamp | undefined)
            ?.toMillis() ?? 0;
          return secondUpdated - firstUpdated;
        })
        .slice(0, candidatePoolLimit);

      console.log(`🔍 Retrieved ${candidateDocuments.length} deduplicated candidates`);

      const matches: ProximityMatch[] = [];
      let totalProcessed = 0;

      // Pre-compute current user's interest set for O(1) lookups
      // const currentInterestsSet = new Set(currentUserProfile.interests);

      for (const doc of candidateDocuments) {
        // Skip current user
        if (doc.id === currentUserUid) continue;

        totalProcessed++;

        try {
          const userProfile = doc.data() as UserProfile;

          const eligibility = discoveryEligibility(
            currentUserProfile,
            currentUserUid,
            userProfile,
            doc.id,
          );
          if (!eligibility) continue;

          const coarseDistanceKm = eligibility.distanceKm < 0.48 ? 0.2 : 0.5;
          matches.push({
            userProfile: publicDiscoverProfile(userProfile, doc.id),
            // Representative band only: clients never receive exact distance
            // or the underlying location document.
            distanceKm: coarseDistanceKm,
            commonInterests: eligibility.commonInterests,
            topSharedInterests: eligibility.topSharedInterests,
            matchScore: eligibility.matchScore
          });

        } catch (error) {
          console.error(`Error processing user ${doc.id}:`, error);
          continue;
        }
      }

      // Sort by match score (highest first) and limit results
      matches.sort((a, b) => b.matchScore - a.matchScore);
      const limitedMatches = matches.slice(0, limit);

      // This is deliberately a count, not an event log. It tells us whether
      // ranking versions lead to waves/matches without retaining who saw whom.
      await recordMetricsBestEffort({
        discoveryRequests: 1,
        profilesShown: limitedMatches.length,
      }, db);

      console.log(`✅ Found ${limitedMatches.length} matches out of ${totalProcessed} processed users`);
      console.log(`⏱️ Execution time: ${Date.now() - startTime}ms`);

      return {
        matches: limitedMatches,
        rankingVersion: discoveryRankingVersion,
        totalProcessed,
        executionTimeMs: Date.now() - startTime
      };

    } catch (error) {
      console.error('Error in findNearbyMatches:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError(
        'internal',
        'An error occurred while finding matches',
        error
      );
    }
  }
);

/**
 * Converts member-owned safety choices into anonymous aggregate outcomes.
 * One update counts at most one action: blocking also adds an unmatch, but is
 * measured as a block rather than double-counting both signals.
 */
export const onSafetyStateUpdated = onDocumentUpdated(
  { document: 'users/{userId}', region: 'us-central1' },
  async (event) => {
    const before = event.data?.before.data()?.safety ?? {};
    const after = event.data?.after.data()?.safety ?? {};
    const metric = hasNewSafetyEntry(before.blockedUserIds, after.blockedUserIds)
      ? 'blocks'
      : hasNewSafetyEntry(before.unmatchedUserIds, after.unmatchedUserIds)
        ? 'unmatches'
        : hasNewSafetyEntry(before.hiddenWaveIds, after.hiddenWaveIds)
          ? 'hides'
          : null;
    if (metric) await recordMetricsBestEffort({ [metric]: 1 });
  },
);

/**
 * Cloud Function to get user profile by UID
 */
export const getUserProfile = onCall(
  { region: 'us-central1' },
  async (request) => {
    const data = request.data as { uid: string };
    const context = request.auth;
    
    // Validate authentication
    if (!context) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { uid } = data;
    if (uid !== context.uid) {
      throw new HttpsError(
        'permission-denied',
        'Profiles are available only through privacy-safe discovery results.',
      );
    }
    const db = admin.firestore();
    
    try {
      const userDoc = await db.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        throw new HttpsError(
          'not-found',
          'User profile not found'
        );
      }

      return userDoc.data();
    } catch (error) {
      console.error('Error in getUserProfile:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError(
        'internal',
        'An error occurred while getting user profile',
        error
      );
    }
  }
);

/**
 * Cloud Function to detect mutual matches and send notifications
 * Triggers when a wave document is created or updated
 */
export const onWaveCreated = onDocumentCreated(
  { document: 'waves/{waveId}', region: 'us-central1' },
  async (event) => {
    const waveData = event.data?.data();
    if (!waveData) return;

    const { senderId, receiverId, status } = waveData;

    // Only process pending waves (new waves)
    if (status !== 'pending') return;

    console.log(`🌊 New wave from ${senderId} to ${receiverId}`);

    try {
      const db = admin.firestore();

      // Check if there's a reverse wave (receiver -> sender)
      const reverseWaveQuery = await db
        .collection('waves')
        .where('senderId', '==', receiverId)
        .where('receiverId', '==', senderId)
        .where('status', '==', 'pending')
        .limit(1)
        .get();

      if (reverseWaveQuery.empty) {
        console.log('No reverse wave found - not a mutual match yet');
        return;
      }

      console.log('🎉 MUTUAL MATCH DETECTED!');

      // Get both user profiles for notification
      const [senderDoc, receiverDoc] = await Promise.all([
        db.collection('users').doc(senderId).get(),
        db.collection('users').doc(receiverId).get(),
      ]);

      if (!senderDoc.exists || !receiverDoc.exists) {
        console.error('User profile not found');
        return;
      }

      const senderProfile = senderDoc.data();
      const receiverProfile = receiverDoc.data();

      // Send notifications to both users
      await Promise.all([
        sendMatchNotification(
          receiverProfile?.fcmToken,
          senderProfile?.displayName || 'Someone',
          receiverId
        ),
        sendMatchNotification(
          senderProfile?.fcmToken,
          receiverProfile?.displayName || 'Someone',
          senderId
        ),
      ]);

      console.log('✅ Match notifications sent successfully');
    } catch (error) {
      console.error('Error processing mutual match:', error);
    }
  }
);

/**
 * Helper function to send a match notification via FCM
 */
async function sendMatchNotification(
  fcmToken: string | undefined,
  matchedUserName: string,
  userId: string
): Promise<void> {
  if (!fcmToken) {
    console.log(`No FCM token for user ${userId}, skipping notification`);
    return;
  }

  try {
    const message = {
      token: fcmToken,
      notification: {
        title: '🤝 New Match!',
        body: `You and ${matchedUserName} are now connected!`,
      },
      data: {
        type: 'mutual_match',
        matchedUserName,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        route: '/waves',
        tab: 'matched',
      },
      android: {
        priority: 'high' as const,
        notification: {
          channelId: 'matches',
          sound: 'default',
          priority: 'high' as const,
          icon: 'ic_notification',
          color: '#4CAF50', // Green color for friendship
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    await admin.messaging().send(message);
    console.log(`✅ Notification sent to ${userId}`);
  } catch (error) {
    console.error(`Error sending notification to ${userId}:`, error);
  }
}
