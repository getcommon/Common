import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';

class ChatService {
  ChatService._();
  static final instance = ChatService._();

  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

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
    final existingId = await findConversationId(currentUserId, otherUserId);
    if (existingId != null) return existingId;
    throw StateError(
      'Conversations are created only after a mutual wave is accepted.',
    );
  }

  /// Send a message in a conversation
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('sendMessage')
          .call<void>({'conversationId': conversationId, 'text': text});
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
    await _functions.httpsCallable('markConversationRead').call<void>({
      'conversationId': conversationId,
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
    await _functions.httpsCallable('removeConversation').call<void>({
      'conversationId': conversationId,
    });

    if (kDebugMode) {
      debugPrint('Deleted conversation $conversationId');
    }
  }
}
