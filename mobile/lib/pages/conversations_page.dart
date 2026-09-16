/// Inbox contains conversations created by mutual waves only.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import 'chat_detail_page.dart';

class ConversationsPage extends StatelessWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in to see your inbox.'));
    }

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Conversation>>(
          stream: ChatService.instance.watchUserConversations(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const _InboxState(
                title: 'Inbox is taking a moment',
                message: 'Check your connection, then try again.',
              );
            }

            final conversations = snapshot.data ?? const <Conversation>[];
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        'Inbox',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.1,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Conversations begin after a mutual wave.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (conversations.isEmpty)
                        const _InboxState(
                          title: 'Your conversations will gather here.',
                          message:
                              'When you both wave, you’ll have a quiet place to say hello.',
                        )
                      else ...[
                        Text(
                          'Connections',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),
                        ...conversations.map(
                          (conversation) => _ConversationRow(
                            conversation: conversation,
                            currentUserId: user.uid,
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.currentUserId,
  });

  final Conversation conversation;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final name = conversation.getOtherParticipantName(currentUserId);
    final photo = conversation.getOtherParticipantPhoto(currentUserId);
    final unread = conversation.getUnreadCountForUser(currentUserId);
    final lastMessage = conversation.lastMessage;
    final sentByMe = conversation.lastMessageSenderId == currentUserId;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            conversationId: conversation.id,
            otherUserId: conversation.getOtherParticipantId(currentUserId),
            otherUserName: name,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            _InboxAvatar(name: name, photoUrl: photo),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                        ),
                      ),
                      if (conversation.lastMessageTime != null)
                        Text(
                          _formatTimestamp(conversation.lastMessageTime!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (sentByMe && lastMessage != null) ...[
                        const Icon(
                          Icons.arrow_upward_rounded,
                          size: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          lastMessage ?? 'Say hello when you’re ready.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: unread > 0
                                    ? AppColors.textPrimaryLight
                                    : AppColors.textSecondaryLight,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
    if (date == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
    if (now.difference(timestamp).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[timestamp.weekday - 1];
    }
    return '${timestamp.month}/${timestamp.day}';
  }
}

class _InboxAvatar extends StatelessWidget {
  const _InboxAvatar({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 27,
    backgroundColor: AppColors.surfaceVariantLight,
    backgroundImage: photoUrl == null || photoUrl!.isEmpty
        ? null
        : NetworkImage(photoUrl!),
    child: photoUrl == null || photoUrl!.isEmpty
        ? Text(
            name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          )
        : null,
  );
}

class _InboxState extends StatelessWidget {
  const _InboxState({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 64),
    child: Column(
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: 38,
          color: AppColors.textSecondaryLight,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryLight),
        ),
      ],
    ),
  );
}
