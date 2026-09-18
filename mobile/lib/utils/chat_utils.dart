import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../services/wave_service.dart';
import '../pages/chat_detail_page.dart';

/// Utility class for chat-related operations
class ChatUtils {
  /// Start a conversation with another user
  /// Opens the chat detail page after creating/finding the conversation
  ///
  /// IMPORTANT: Requires mutual wave (both users must have waved at each other)
  static Future<void> startConversationWith(
    BuildContext context,
    String otherUserId,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Check for mutual match first
      final hasMutualMatch = await WaveService.instance.checkMutualMatch(
        currentUser.uid,
        otherUserId,
      );

      if (!hasMutualMatch) {
        if (context.mounted) Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You need to wave at each other before messaging!'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final conversationId = await ChatService.instance.findConversationId(
        currentUser.uid,
        otherUserId,
      );
      if (conversationId == null) {
        if (context.mounted) Navigator.of(context).pop();
        throw Exception('Your conversation is still being prepared.');
      }

      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Navigate to chat detail page
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              conversationId: conversationId,
              otherUserId: otherUserId,
              otherUserName: 'Connection',
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (context.mounted) Navigator.of(context).pop();

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
