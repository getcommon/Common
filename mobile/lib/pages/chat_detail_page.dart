import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/safety_service.dart';
import '../core/theme/app_colors.dart';

class ChatDetailPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;

  const ChatDetailPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final String _currentUserId;
  int _previousMessageCount = 0;
  final Map<String, int> _messagePositions =
      {}; // Track message positions for smooth transitions
  DateTime? _lastMarkedAsReadTime;
  static const _markAsReadThrottle = Duration(
    seconds: 2,
  ); // Throttle to avoid too many updates

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // User signed out during navigation - pop back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      _currentUserId = '';
      return;
    }
    _currentUserId = user.uid;
    // Mark conversation as read when entering
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    final now = DateTime.now();
    // Throttle updates to avoid too many Firestore writes
    if (_lastMarkedAsReadTime != null &&
        now.difference(_lastMarkedAsReadTime!) < _markAsReadThrottle) {
      return;
    }
    _lastMarkedAsReadTime = now;
    await ChatService.instance.markConversationAsRead(
      widget.conversationId,
      _currentUserId,
    );
  }

  @override
  void dispose() {
    // Mark as read one final time when leaving to ensure all viewed messages are marked
    // Force update even if throttled (bypass throttle check)
    ChatService.instance.markConversationAsRead(
      widget.conversationId,
      _currentUserId,
    );
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Clear input immediately for better UX
    _messageController.clear();

    try {
      await ChatService.instance.sendMessage(
        conversationId: widget.conversationId,
        senderId: _currentUserId,
        text: text,
      );

      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              'Connected through Common',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_SafetyAction>(
            tooltip: 'Conversation options',
            onSelected: _handleSafetyAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _SafetyAction.unmatch,
                child: Text('Unmatch'),
              ),
              PopupMenuItem(value: _SafetyAction.block, child: Text('Block')),
              PopupMenuItem(value: _SafetyAction.report, child: Text('Report')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: ChatService.instance.watchConversationMessages(
                widget.conversationId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  _previousMessageCount = 0;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 38,
                          color: AppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your conversation starts here.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a simple hello, or ask about something you have in common.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  );
                }

                // Only auto-scroll when a new message is actually added (count increases)
                // This prevents jumping when messages re-sort due to timestamp resolution
                final hasNewMessage = messages.length > _previousMessageCount;
                if (hasNewMessage) {
                  _previousMessageCount = messages.length;

                  // Check if any new messages are from the other user
                  // If so, mark as read since user is actively viewing
                  if (messages.isNotEmpty) {
                    final latestMessage = messages.last;
                    if (latestMessage.senderId != _currentUserId) {
                      // New message from other user while viewing - mark as read
                      _markAsRead();
                    }
                  }

                  // Auto-scroll to bottom when new messages arrive
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                } else {
                  // Update count even if no new message (handles initial load)
                  _previousMessageCount = messages.length;
                }

                // Update message positions and detect changes
                final Map<String, int> newPositions = {};
                for (int i = 0; i < messages.length; i++) {
                  newPositions[messages[i].id] = i;
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUserId;
                    final previousIndex = _messagePositions[message.id];
                    final isNewPosition =
                        previousIndex != null && previousIndex != index;
                    final previousIndexValue = previousIndex ?? index;

                    // Update position
                    _messagePositions[message.id] = index;

                    return TweenAnimationBuilder<double>(
                      key: ValueKey(
                        '${message.id}_${message.sequence}',
                      ), // Stable key with sequence
                      tween: Tween<double>(
                        begin: isNewPosition
                            ? (previousIndexValue < index ? -1.0 : 1.0)
                            : 0.0,
                        end: 0.0,
                      ),
                      duration: isNewPosition
                          ? const Duration(milliseconds: 300)
                          : const Duration(milliseconds: 0),
                      curve: Curves.easeOut,
                      builder: (context, offset, child) {
                        return Transform.translate(
                          offset: Offset(
                            0,
                            offset * 20,
                          ), // Subtle slide animation
                          child: Opacity(
                            opacity: isNewPosition
                                ? (1.0 - (offset.abs() * 0.3).clamp(0.0, 0.3))
                                : 1.0,
                            child: child,
                          ),
                        );
                      },
                      child: _AnimatedMessageBubble(
                        message: message,
                        isMe: isMe,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _MessageInput(controller: _messageController, onSend: _sendMessage),
        ],
      ),
    );
  }

  Future<void> _handleSafetyAction(_SafetyAction action) async {
    final label = switch (action) {
      _SafetyAction.unmatch => 'Unmatch',
      _SafetyAction.block => 'Block',
      _SafetyAction.report => 'Report',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$label ${widget.otherUserName}?'),
        content: Text(
          action == _SafetyAction.report
              ? 'This sends a private report to Common’s moderation team.'
              : action == _SafetyAction.block
              ? 'They will no longer be able to contact you or appear in your activity.'
              : 'This removes this conversation from your inbox. You can’t undo it here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (action == _SafetyAction.report) {
      await SafetyService.instance.report(
        reporterId: _currentUserId,
        subjectId: widget.otherUserId,
        conversationId: widget.conversationId,
        reason: 'Member report',
      );
    } else {
      if (action == _SafetyAction.block) {
        await SafetyService.instance.block(_currentUserId, widget.otherUserId);
      } else {
        await SafetyService.instance.unmatch(
          _currentUserId,
          widget.otherUserId,
        );
      }
      await ChatService.instance.deleteConversation(widget.conversationId);
    }
    if (!mounted) return;
    if (action != _SafetyAction.report) Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == _SafetyAction.report ? 'Report sent.' : '$label complete.',
        ),
      ),
    );
  }
}

enum _SafetyAction { unmatch, block, report }

class _AnimatedMessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;

  const _AnimatedMessageBubble({required this.message, required this.isMe});

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _MessageBubble(message: widget.message, isMe: widget.isMe),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: ValueKey(message.id), // Stable key for smooth re-sorting
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surfaceVariantLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : AppColors.textSecondaryLight,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dt.year, dt.month, dt.day);

    if (messageDate == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInput({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Write a message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceVariantLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onSend,
              icon: const Icon(
                Icons.arrow_upward_rounded,
                color: AppColors.primary,
              ),
              iconSize: 23,
            ),
          ],
        ),
      ),
    );
  }
}
