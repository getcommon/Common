import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';

class ChatService {
  ChatService._();
  static final instance = ChatService._();

  final _db = FirebaseFirestore.instance;

  /// Finds the server-created conversation for a mutual connection.
  Future<String?> findConversationId(
    String currentUserId,
    String otherUserId,
  ) async {
    final snapshot = await _db
        .collection('conversations')
        .where('participantIds', arrayContains: currentUserId)
        .get();
    for (final document in snapshot.docs) {
      final participants =
          (document.data()['participantIds'] as List?)?.cast<String>() ??
          const <String>[];
      if (participants.contains(otherUserId)) return document.id;
    }
    return null;
  }

  /// Get or create a conversation between two users
  Future<String> getOrCreateConversation(
    String currentUserId,
    String otherUserId,
    Map<String, dynamic> currentUserProfile,
    Map<String, dynamic> otherUserProfile,
  ) async {
    try {
      // Check if conversation already exists
      final existingQuery = await _db
          .collection('conversations')
          .where('participantIds', arrayContains: currentUserId)
          .get();

      // Find conversation with both participants
      for (final doc in existingQuery.docs) {
        final participantIds = (doc.data()['participantIds'] as List)
            .cast<String>();
        if (participantIds.contains(otherUserId)) {
          return doc.id;
        }
      }

      // Create new conversation
      final conversationRef = _db.collection('conversations').doc();
      final now = DateTime.now();
      final conversation = Conversation(
        id: conversationRef.id,
        participantIds: [currentUserId, otherUserId],
        participantProfiles: {
          currentUserId: currentUserProfile,
          otherUserId: otherUserProfile,
        },
        unreadCount: {currentUserId: 0, otherUserId: 0},
        createdAt: now,
        lastMessageTime: now, // Initialize with createdAt so orderBy works
      );

      await conversationRef.set(conversation.toMap());
      return conversationRef.id;
    } catch (e) {
      debugPrint('Error in getOrCreateConversation: $e');
      rethrow;
    }
  }

  /// Send a message in a conversation
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    try {
      // Atomically increment sequence counter for this conversation using a transaction
      // This ensures messages sent simultaneously get unique, ordered sequence numbers
      final counterRef = _db
          .collection('conversations')
          .doc(conversationId)
          .collection('_counters')
          .doc('messages');

      final nextSequence = await _db.runTransaction<int>((transaction) async {
        final counterDoc = await transaction.get(counterRef);
        int sequence;
        if (counterDoc.exists) {
          sequence = (counterDoc.data()?['sequence'] as int?) ?? 0;
          sequence++;
          transaction.update(counterRef, {'sequence': sequence});
        } else {
          sequence = 1;
          transaction.set(counterRef, {'sequence': sequence});
        }
        return sequence;
      });

      // Use Firebase server timestamp (Unix time from server, NOT device time)
      // Add sequence number to ensure correct ordering when timestamps are identical
      await _db.collection('messages').add({
        'conversationId': conversationId,
        'senderId': senderId,
        'text': text,
        'timestamp':
            FieldValue.serverTimestamp(), // Server Unix timestamp, not device time
        'sequence':
            nextSequence, // Sequence number for tie-breaking (atomically assigned)
        'isRead': false,
      });

      // Get conversation to update unread counts
      final convDoc = await _db
          .collection('conversations')
          .doc(conversationId)
          .get();
      if (!convDoc.exists) return;

      final conv = Conversation.fromMap(convDoc.id, convDoc.data()!);
      final newUnreadCount = Map<String, int>.from(conv.unreadCount);

      // Increment unread count for all participants except sender
      for (final participantId in conv.participantIds) {
        if (participantId != senderId) {
          newUnreadCount[participantId] =
              (newUnreadCount[participantId] ?? 0) + 1;
        }
      }

      // Update conversation with last message info
      await _db.collection('conversations').doc(conversationId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount': newUnreadCount,
      });
    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      rethrow;
    }
  }

  /// Mark all messages in a conversation as read for a user
  /// Also stores the last viewed timestamp to calculate unread count accurately
  /// This immediately sets unread count to 0 and updates lastViewed timestamp
  /// Uses the latest message timestamp from the other user to ensure all visible messages are marked as read
  Future<void> markConversationAsRead(
    String conversationId,
    String userId,
  ) async {
    // Get the conversation to find the other user
    final convDoc = await _db
        .collection('conversations')
        .doc(conversationId)
        .get();
    if (!convDoc.exists) return;

    final conv = Conversation.fromMap(convDoc.id, convDoc.data()!);
    final otherUserId = conv.getOtherParticipantId(userId);

    // Get the latest message from the other user to use its timestamp
    // This ensures all messages visible when viewing are marked as read
    final latestMessageQuery = await _db
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('senderId', isEqualTo: otherUserId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    Timestamp lastViewedTimestamp;
    if (latestMessageQuery.docs.isNotEmpty) {
      // Use the latest message's timestamp (or slightly after to account for any edge cases)
      final latestMessage = latestMessageQuery.docs.first;
      final latestTimestamp = latestMessage.data()['timestamp'] as Timestamp?;
      if (latestTimestamp != null) {
        // Use the latest message timestamp to mark all visible messages as read
        lastViewedTimestamp = latestTimestamp;
      } else {
        // Fallback to server timestamp if message timestamp is not yet resolved
        lastViewedTimestamp = Timestamp.now();
      }
    } else {
      // No messages from other user yet, use server timestamp
      lastViewedTimestamp = Timestamp.now();
    }

    // Update conversation with unread count = 0 and lastViewed timestamp
    // Using the latest message timestamp ensures all visible messages are marked as read
    await _db.collection('conversations').doc(conversationId).update({
      'unreadCount.$userId': 0,
      'lastViewed.$userId': lastViewedTimestamp,
    });
  }

  /// Watch all conversations for a user (ordered by last message time)
  /// Calculates accurate unread counts by counting messages from other user
  Stream<List<Conversation>> watchUserConversations(String userId) async* {
    await for (final snapshot
        in _db
            .collection('conversations')
            .where('participantIds', arrayContains: userId)
            .snapshots()) {
      final conversations = <Conversation>[];

      for (final doc in snapshot.docs) {
        final conv = Conversation.fromMap(doc.id, doc.data());
        final otherUserId = conv.getOtherParticipantId(userId);

        // Calculate actual unread count: messages from other user after last viewed
        final lastViewed =
            (doc.data()['lastViewed'] as Map<String, dynamic>?)?[userId];
        DateTime? lastViewedTime;
        if (lastViewed != null) {
          if (lastViewed is Timestamp) {
            lastViewedTime = lastViewed.toDate();
          }
        }

        // Count messages from other user that arrived after last viewed
        int actualUnreadCount = 0;
        if (lastViewedTime != null) {
          final unreadMessages = await _db
              .collection('messages')
              .where('conversationId', isEqualTo: conv.id)
              .where(
                'senderId',
                isEqualTo: otherUserId,
              ) // Only messages from OTHER user
              .where(
                'timestamp',
                isGreaterThan: Timestamp.fromDate(lastViewedTime),
              )
              .get();
          actualUnreadCount = unreadMessages.docs.length;
        } else {
          // If never viewed, count all messages from other user
          final allMessages = await _db
              .collection('messages')
              .where('conversationId', isEqualTo: conv.id)
              .where(
                'senderId',
                isEqualTo: otherUserId,
              ) // Only messages from OTHER user
              .get();
          actualUnreadCount = allMessages.docs.length;
        }

        // Update unread count in conversation object
        final updatedUnreadCount = Map<String, int>.from(conv.unreadCount);
        updatedUnreadCount[userId] = actualUnreadCount;

        conversations.add(
          Conversation(
            id: conv.id,
            participantIds: conv.participantIds,
            participantProfiles: conv.participantProfiles,
            lastMessage: conv.lastMessage,
            lastMessageTime: conv.lastMessageTime,
            lastMessageSenderId: conv.lastMessageSenderId,
            unreadCount: updatedUnreadCount,
            createdAt: conv.createdAt,
          ),
        );
      }

      // Sort in-app by lastMessageTime (most recent first)
      conversations.sort((a, b) {
        final aTime = a.lastMessageTime ?? a.createdAt;
        final bTime = b.lastMessageTime ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      yield conversations;
    }
  }

  /// Watch messages in a conversation (ordered by timestamp)
  Stream<List<Message>> watchConversationMessages(String conversationId) {
    return _db
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => Message.fromMap(doc.id, doc.data()))
              .toList();

          // Client-side sort: PRIMARY by sequence number (atomically assigned, always correct)
          // SECONDARY by timestamp (for display purposes only)
          // This ensures messages appear in correct order immediately, even if timestamps are unresolved
          messages.sort((a, b) {
            // Primary sort: sequence number (always correct, assigned atomically)
            final sequenceCompare = a.sequence.compareTo(b.sequence);
            if (sequenceCompare != 0) return sequenceCompare;
            // Secondary sort: timestamp (for messages with same sequence - shouldn't happen)
            return a.timestamp.compareTo(b.timestamp);
          });

          return messages;
        });
  }

  /// Get a single conversation by ID
  Future<Conversation?> getConversation(String conversationId) async {
    final doc = await _db.collection('conversations').doc(conversationId).get();
    if (!doc.exists) return null;
    return Conversation.fromMap(doc.id, doc.data()!);
  }

  /// Delete a conversation and all its messages
  Future<void> deleteConversation(String conversationId) async {
    // Delete all messages in the conversation
    final messages = await _db
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .get();

    final batch = _db.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Delete the conversation
    batch.delete(_db.collection('conversations').doc(conversationId));

    await batch.commit();

    if (kDebugMode) {
      debugPrint('Deleted conversation $conversationId');
    }
  }
}
