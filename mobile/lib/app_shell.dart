// lib/app_shell.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/profile_service.dart';
import 'services/chat_service.dart';
import 'services/wave_service.dart';
import 'models/user_profile.dart';
import 'models/chat_models.dart';
import 'models/wave_models.dart';
import 'pages/profile_page.dart';
import 'pages/conversations_page.dart';
import 'pages/home_page.dart';
import 'pages/waves_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<UserProfile?>(
      stream: ProfileService.instance.watchProfile(u.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pages = [
          HomePage(
            // Pass callback to navigate between tabs
            onNavigateToTab: (index) => setState(() => _currentIndex = index),
          ),
          const ActivityPage(),
          const ConversationsPage(),
          const ProfilePage(),
        ];

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: pages),
          bottomNavigationBar: _BottomNav(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            userId: u.uid,
          ),
        );
      },
    );
  }
}

/// Bottom navigation bar with unread message badge
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String userId;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = Theme.of(context).colorScheme.primary;

    // Watch conversations and the incoming updates shown in Activity.
    return StreamBuilder<List<Conversation>>(
      stream: ChatService.instance.watchUserConversations(userId),
      builder: (context, conversationsSnapshot) {
        // Calculate total unread messages
        int totalUnread = 0;
        if (conversationsSnapshot.hasData) {
          for (var conversation in conversationsSnapshot.data!) {
            totalUnread += conversation.getUnreadCountForUser(userId);
          }
        }

        // Activity only needs a badge for waves that still need a response.
        return StreamBuilder<List<WaveRequest>>(
          stream: WaveService.instance.watchIncomingWaves(userId),
          builder: (context, wavesSnapshot) {
            // Count pending incoming waves
            int pendingWaves = wavesSnapshot.data?.length ?? 0;

            return BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: onTap,
              type: BottomNavigationBarType.fixed,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  label: 'Discover',
                ),
                BottomNavigationBarItem(
                  icon: pendingWaves > 0
                      ? Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.favorite_border),
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  pendingWaves > 99
                                      ? '99+'
                                      : pendingWaves.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Icon(Icons.favorite_border),
                  label: 'Activity',
                ),
                BottomNavigationBarItem(
                  icon: totalUnread > 0
                      ? Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.chat_bubble_outline),
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  totalUnread > 99
                                      ? '99+'
                                      : totalUnread.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Icon(Icons.chat_bubble_outline),
                  label: 'Inbox',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            );
          },
        );
      },
    );
  }
}
