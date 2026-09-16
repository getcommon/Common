/// Activity collects only meaningful connection updates: incoming waves and
/// mutual connections. Sent waves stay intentionally quiet on Discover.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/wave_models.dart';
import '../services/wave_service.dart';
import '../utils/chat_utils.dart';

class WavesPage extends StatelessWidget {
  const WavesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in to see your activity.'));
    }

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<WaveRequest>>(
          stream: WaveService.instance.watchIncomingWaves(user.uid),
          builder: (context, wavesSnapshot) {
            return StreamBuilder<List<MutualMatch>>(
              stream: WaveService.instance.watchMutualMatches(user.uid),
              builder: (context, matchesSnapshot) {
                if (wavesSnapshot.connectionState == ConnectionState.waiting ||
                    matchesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final waves = wavesSnapshot.data ?? const <WaveRequest>[];
                final matches = matchesSnapshot.data ?? const <MutualMatch>[];
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Text(
                            'Activity',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1.1,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'The people you’ve made a little room for.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 32),
                          if (matches.isNotEmpty) ...[
                            const _SectionHeading('Connections'),
                            const SizedBox(height: 12),
                            ...matches.map(
                              (match) => _ConnectionRow(
                                match: match,
                                currentUserId: user.uid,
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                          if (waves.isNotEmpty) ...[
                            const _SectionHeading('Waves for you'),
                            const SizedBox(height: 12),
                            ...waves.map(
                              (wave) => _IncomingWaveRow(
                                wave: wave,
                                onAccept: () => _acceptWave(context, wave),
                                onDecline: () => _declineWave(context, wave),
                              ),
                            ),
                          ],
                          if (matches.isEmpty && waves.isEmpty)
                            const _ActivityEmptyState(),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _acceptWave(BuildContext context, WaveRequest wave) async {
    final matchId = await WaveService.instance.acceptWave(wave.id);
    if (!context.mounted || matchId == null) return;
    final name = wave.senderProfile['displayName'] as String? ?? 'them';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You and $name are connected.',
              style: Theme.of(
                sheetContext,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'Start with a simple hello whenever it feels right.',
              style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await ChatUtils.startConversationWith(context, wave.senderId);
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Start conversation'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _declineWave(BuildContext context, WaveRequest wave) async {
    final declined = await WaveService.instance.declineWave(wave.id);
    if (!context.mounted || !declined) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wave removed from your activity.')),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
  );
}

class _IncomingWaveRow extends StatelessWidget {
  const _IncomingWaveRow({
    required this.wave,
    required this.onAccept,
    required this.onDecline,
  });

  final WaveRequest wave;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final name = wave.senderProfile['displayName'] as String? ?? 'Someone';
    final photo = wave.senderProfile['photoUrl'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActivityAvatar(name: name, photoUrl: photo),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name waved to you',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  wave.timeAgo,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: onAccept,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Wave back'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onDecline,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondaryLight,
                      ),
                      child: const Text('Not now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({required this.match, required this.currentUserId});
  final MutualMatch match;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final profile = match.getOtherUserProfile(currentUserId);
    final name = profile['displayName'] as String? ?? 'Someone';
    final photo = profile['photoUrl'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          _ActivityAvatar(name: name, photoUrl: photo),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected with $name',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  'You can message each other now.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ChatUtils.startConversationWith(
              context,
              match.getOtherUserId(currentUserId),
            ),
            icon: const Icon(Icons.chat_bubble_outline),
            color: AppColors.primary,
            tooltip: 'Start conversation',
          ),
        ],
      ),
    );
  }
}

class _ActivityAvatar extends StatelessWidget {
  const _ActivityAvatar({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: AppColors.surfaceVariantLight,
      backgroundImage: photoUrl == null || photoUrl!.isEmpty
          ? null
          : NetworkImage(photoUrl!),
      child: photoUrl == null || photoUrl!.isEmpty
          ? Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 88),
    child: Column(
      children: [
        Icon(
          Icons.waving_hand_outlined,
          size: 38,
          color: AppColors.textSecondaryLight,
        ),
        const SizedBox(height: 16),
        Text(
          'A quiet start is still a start.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'When someone waves back—or reaches out—you’ll see it here.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryLight),
        ),
      ],
    ),
  );
}
