import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/wave_models.dart';

/// Service for managing wave requests and mutual matches
class WaveService {
  WaveService._();
  static final instance = WaveService._();

  /// Starting limit from the product brief. Keep this here so the UI and the
  /// write path use the same rule while the final limit is still tunable.
  static const int dailyWaveLimit = 3;

  final _db = FirebaseFirestore.instance;

  /// Send a wave to another user
  ///
  /// Returns the wave ID if successful, null if a wave already exists
  Future<String?> sendWave({
    required String senderId,
    required String receiverId,
    required Map<String, dynamic> senderProfile,
    required Map<String, dynamic> receiverProfile,
  }) async {
    try {
      if (await wavesSentToday(senderId) >= dailyWaveLimit) {
        throw StateError('Daily wave limit reached');
      }

      // Check if wave already exists (in either direction)
      final existingWave = await _checkExistingWave(senderId, receiverId);
      if (existingWave != null) {
        debugPrint('Wave already exists: ${existingWave.id}');
        return null;
      }

      // Create new wave request
      final waveRef = _db.collection('waves').doc();
      final wave = WaveRequest(
        id: waveRef.id,
        senderId: senderId,
        receiverId: receiverId,
        timestamp: DateTime.now(),
        status: WaveStatus.pending,
        senderProfile: senderProfile,
        receiverProfile: receiverProfile,
      );

      await waveRef.set(wave.toMap());
      debugPrint('✋ Wave sent from $senderId to $receiverId');

      return waveRef.id;
    } catch (e) {
      debugPrint('Error sending wave: $e');
      return null;
    }
  }

  /// Watches every wave created by this person since their local day began.
  /// Accepted and declined waves still count: the limit is on sends, not
  /// outstanding requests.
  Stream<int> watchWavesSentToday(String userId) {
    final startOfToday = _startOfToday();
    return _db
        .collection('waves')
        .where('senderId', isEqualTo: userId)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<int> wavesSentToday(String userId) async {
    final snapshot = await _db
        .collection('waves')
        .where('senderId', isEqualTo: userId)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfToday()),
        )
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.length;
  }

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Accept an incoming wave
  ///
  /// BEST PRACTICE: Accepting a wave means you wave back automatically
  /// This follows the pattern of Bumble/Tinder where mutual interest = match
  /// Returns the match ID if a mutual match was created, null otherwise
  Future<String?> acceptWave(String waveId) async {
    try {
      final wave = await getWave(waveId);
      if (wave == null) {
        debugPrint('Wave not found: $waveId');
        return null;
      }

      if (wave.status != WaveStatus.pending) {
        debugPrint('Wave already responded to: $waveId');
        return null;
      }

      // Step 1: Accept the incoming wave
      await _db.collection('waves').doc(waveId).update({
        'status': WaveStatus.accepted.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Wave accepted: $waveId');

      // Step 2: Automatically create an ACCEPTED wave back
      // This is the key difference - we create an already-accepted reverse wave
      final existingReverseWave = await _getWaveInAnyStatus(
        wave.receiverId,
        wave.senderId,
      );

      String? reverseWaveId;
      if (existingReverseWave == null) {
        // Create reverse wave as ACCEPTED (not pending)
        debugPrint(
          '👋 Auto-waving back from ${wave.receiverId} to ${wave.senderId}',
        );
        final reverseRef = _db.collection('waves').doc();
        final reverseWave = WaveRequest(
          id: reverseRef.id,
          senderId: wave.receiverId,
          receiverId: wave.senderId,
          timestamp: DateTime.now(),
          status: WaveStatus.accepted, // Already accepted!
          respondedAt: DateTime.now(),
          senderProfile: wave.receiverProfile,
          receiverProfile: wave.senderProfile,
        );
        await reverseRef.set(reverseWave.toMap());
        reverseWaveId = reverseRef.id;
      } else if (existingReverseWave.status == WaveStatus.pending) {
        // If they already waved at us, accept their wave too
        await _db.collection('waves').doc(existingReverseWave.id).update({
          'status': WaveStatus.accepted.name,
          'respondedAt': FieldValue.serverTimestamp(),
        });
        reverseWaveId = existingReverseWave.id;
      }

      // Step 3: Create mutual match and conversation
      final matchId = await _createMutualMatch(
        wave.id,
        reverseWaveId ?? '',
        wave.senderId,
        wave.receiverId,
        wave.senderProfile,
        wave.receiverProfile,
      );

      return matchId; // Return match ID if match was created
    } catch (e) {
      debugPrint('Error accepting wave: $e');
      return null;
    }
  }

  /// Decline an incoming wave
  Future<bool> declineWave(String waveId) async {
    try {
      final wave = await getWave(waveId);
      if (wave == null) {
        debugPrint('Wave not found: $waveId');
        return false;
      }

      if (wave.status != WaveStatus.pending) {
        debugPrint('Wave already responded to: $waveId');
        return false;
      }

      // Update wave status to declined
      await _db.collection('waves').doc(waveId).update({
        'status': WaveStatus.declined.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('❌ Wave declined: $waveId');
      return true;
    } catch (e) {
      debugPrint('Error declining wave: $e');
      return false;
    }
  }

  /// Cancel a sent wave (withdraw it)
  Future<bool> cancelWave(String waveId) async {
    try {
      final wave = await getWave(waveId);
      if (wave == null) {
        debugPrint('Wave not found: $waveId');
        return false;
      }

      if (wave.status != WaveStatus.pending) {
        debugPrint('Cannot cancel wave that is not pending: $waveId');
        return false;
      }

      // Delete the wave
      await _db.collection('waves').doc(waveId).delete();
      debugPrint('🗑️ Wave cancelled: $waveId');
      return true;
    } catch (e) {
      debugPrint('Error cancelling wave: $e');
      return false;
    }
  }

  /// Get a single wave by ID
  Future<WaveRequest?> getWave(String waveId) async {
    try {
      final doc = await _db.collection('waves').doc(waveId).get();
      if (!doc.exists) return null;
      return WaveRequest.fromMap(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('Error getting wave: $e');
      return null;
    }
  }

  /// Watch incoming waves for a user (waves sent TO this user)
  Stream<List<WaveRequest>> watchIncomingWaves(String userId) {
    return _db
        .collection('waves')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: WaveStatus.pending.name)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WaveRequest.fromMap(doc.id, doc.data()))
              .where((wave) => !wave.isExpired) // Filter out expired waves
              .toList(),
        );
  }

  /// Watch outgoing waves for a user (waves sent BY this user)
  Stream<List<WaveRequest>> watchOutgoingWaves(String userId) {
    return _db
        .collection('waves')
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: WaveStatus.pending.name)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WaveRequest.fromMap(doc.id, doc.data()))
              .where((wave) => !wave.isExpired) // Filter out expired waves
              .toList(),
        );
  }

  /// Get all waves for a user (both incoming and outgoing)
  Stream<List<WaveRequest>> watchAllWaves(String userId) {
    return _db
        .collection('waves')
        .where('status', isEqualTo: WaveStatus.pending.name)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => WaveRequest.fromMap(doc.id, doc.data()))
              .where(
                (wave) =>
                    (wave.senderId == userId || wave.receiverId == userId) &&
                    !wave.isExpired,
              )
              .toList();
        });
  }

  /// Check if a mutual match exists between two users
  Future<bool> checkMutualMatch(String user1Id, String user2Id) async {
    try {
      // Check if there's an accepted wave from user1 to user2
      final wave1Query = await _db
          .collection('waves')
          .where('senderId', isEqualTo: user1Id)
          .where('receiverId', isEqualTo: user2Id)
          .where('status', isEqualTo: WaveStatus.accepted.name)
          .limit(1)
          .get();

      // Check if there's an accepted wave from user2 to user1
      final wave2Query = await _db
          .collection('waves')
          .where('senderId', isEqualTo: user2Id)
          .where('receiverId', isEqualTo: user1Id)
          .where('status', isEqualTo: WaveStatus.accepted.name)
          .limit(1)
          .get();

      final hasMutualMatch =
          wave1Query.docs.isNotEmpty && wave2Query.docs.isNotEmpty;

      if (hasMutualMatch) {
        debugPrint('🤝 Mutual match exists between $user1Id and $user2Id');
      } else {
        debugPrint('❌ No mutual match between $user1Id and $user2Id');
        debugPrint(
          '   Wave1 ($user1Id → $user2Id): ${wave1Query.docs.length} docs',
        );
        debugPrint(
          '   Wave2 ($user2Id → $user1Id): ${wave2Query.docs.length} docs',
        );
      }

      return hasMutualMatch;
    } catch (e) {
      debugPrint('⚠️ Error checking mutual match: $e');
      debugPrint(
        '   This usually means Firestore security rules need to be updated!',
      );
      // Return false to be safe - don't allow messaging without proper permission check
      return false;
    }
  }

  /// Check if current user has a PENDING wave to another user
  Future<WaveRequest?> getWaveTo(String senderId, String receiverId) async {
    try {
      final query = await _db
          .collection('waves')
          .where('senderId', isEqualTo: senderId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: WaveStatus.pending.name)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return WaveRequest.fromMap(query.docs.first.id, query.docs.first.data());
    } catch (e) {
      debugPrint('Error getting wave: $e');
      return null;
    }
  }

  /// Check if there's an existing pending wave between two users (either direction)
  Future<WaveRequest?> _checkExistingWave(
    String user1Id,
    String user2Id,
  ) async {
    try {
      // Check wave from user1 to user2
      final wave1Query = await _db
          .collection('waves')
          .where('senderId', isEqualTo: user1Id)
          .where('receiverId', isEqualTo: user2Id)
          .where('status', isEqualTo: WaveStatus.pending.name)
          .limit(1)
          .get();

      if (wave1Query.docs.isNotEmpty) {
        return WaveRequest.fromMap(
          wave1Query.docs.first.id,
          wave1Query.docs.first.data(),
        );
      }

      return null;
    } catch (e) {
      debugPrint('Error checking existing wave: $e');
      return null;
    }
  }

  /// Create a mutual match and start a conversation
  /// Returns the match ID if successful
  Future<String?> _createMutualMatch(
    String wave1Id,
    String wave2Id,
    String user1Id,
    String user2Id,
    Map<String, dynamic> user1Profile,
    Map<String, dynamic> user2Profile,
  ) async {
    try {
      // Check if match already exists
      final existingMatch = await _db
          .collection('mutual_matches')
          .where('user1Id', isEqualTo: user1Id)
          .where('user2Id', isEqualTo: user2Id)
          .limit(1)
          .get();

      if (existingMatch.docs.isNotEmpty) {
        debugPrint('Match already exists between $user1Id and $user2Id');
        return existingMatch.docs.first.id;
      }

      // Check reverse direction too
      final existingMatchReverse = await _db
          .collection('mutual_matches')
          .where('user1Id', isEqualTo: user2Id)
          .where('user2Id', isEqualTo: user1Id)
          .limit(1)
          .get();

      if (existingMatchReverse.docs.isNotEmpty) {
        debugPrint('Match already exists between $user2Id and $user1Id');
        return existingMatchReverse.docs.first.id;
      }

      debugPrint('🎉 MUTUAL MATCH detected between $user1Id and $user2Id!');

      // Create mutual match record
      final matchRef = _db.collection('mutual_matches').doc();
      final match = MutualMatch(
        user1Id: user1Id,
        user2Id: user2Id,
        matchedAt: DateTime.now(),
        wave1Id: wave1Id,
        wave2Id: wave2Id,
        user1Profile: user1Profile,
        user2Profile: user2Profile,
      );

      await matchRef.set(match.toMap());
      debugPrint('✅ Mutual match record created: ${matchRef.id}');

      // Create conversation automatically
      await _createConversationForMatch(user1Id, user2Id);

      return matchRef.id;
    } catch (e) {
      debugPrint('Error creating mutual match: $e');
      return null;
    }
  }

  /// Create a conversation for a mutual match
  Future<void> _createConversationForMatch(
    String user1Id,
    String user2Id,
  ) async {
    try {
      // Check if conversation already exists
      final existingConvo = await _db
          .collection('conversations')
          .where('participants', arrayContains: user1Id)
          .get();

      for (final doc in existingConvo.docs) {
        final participants = List<String>.from(
          doc.data()['participants'] as List,
        );
        if (participants.contains(user2Id)) {
          debugPrint(
            'Conversation already exists between $user1Id and $user2Id',
          );
          return;
        }
      }

      // Create new conversation
      final convoRef = _db.collection('conversations').doc();
      await convoRef.set({
        'participants': [user1Id, user2Id],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': 'You matched! Start chatting.',
        'lastMessageSenderId': null,
      });

      debugPrint('💬 Conversation created: ${convoRef.id}');
    } catch (e) {
      debugPrint('Error creating conversation: $e');
    }
  }

  /// Get all mutual matches for a user
  Stream<List<MutualMatch>> watchMutualMatches(String userId) {
    return _db.collection('mutual_matches').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MutualMatch.fromMap(doc.data()))
          .where((match) => match.user1Id == userId || match.user2Id == userId)
          .toList()
        ..sort((a, b) => b.matchedAt.compareTo(a.matchedAt));
    });
  }

  /// Get a wave in any status (helper method)
  Future<WaveRequest?> _getWaveInAnyStatus(
    String senderId,
    String receiverId,
  ) async {
    try {
      final query = await _db
          .collection('waves')
          .where('senderId', isEqualTo: senderId)
          .where('receiverId', isEqualTo: receiverId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return WaveRequest.fromMap(query.docs.first.id, query.docs.first.data());
    } catch (e) {
      debugPrint('Error getting wave: $e');
      return null;
    }
  }

  /// Clean up expired waves (older than 48 hours)
  ///
  /// This should be called periodically or via a Cloud Function
  Future<void> cleanupExpiredWaves() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 48));

      final expiredWaves = await _db
          .collection('waves')
          .where('status', isEqualTo: WaveStatus.pending.name)
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      final batch = _db.batch();
      for (final doc in expiredWaves.docs) {
        batch.update(doc.reference, {'status': WaveStatus.expired.name});
      }

      await batch.commit();
      debugPrint('🧹 Cleaned up ${expiredWaves.docs.length} expired waves');
    } catch (e) {
      debugPrint('Error cleaning up expired waves: $e');
    }
  }
}
