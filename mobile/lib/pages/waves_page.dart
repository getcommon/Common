/// Activity keeps only the meaningful next steps: received waves and
/// conversations opened by a mutual wave. Sent waves stay quietly on Discover.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/wave_models.dart';
import '../services/safety_service.dart';
import '../services/wave_service.dart';
import '../utils/chat_utils.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in to see activity.'));
    }

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<WaveRequest>>(
          stream: WaveService.instance.watchIncomingWaves(user.uid),
          builder: (context, waveSnapshot) => StreamBuilder<List<MutualMatch>>(
            stream: WaveService.instance.watchMutualMatches(user.uid),
            builder: (context, connectionSnapshot) {
              final waves = waveSnapshot.data ?? const <WaveRequest>[];
              final connections =
                  connectionSnapshot.data ?? const <MutualMatch>[];
              return StreamBuilder<SafetyState>(
                stream: SafetyService.instance.watchSafety(user.uid),
                builder: (context, safetySnapshot) {
                  final safety = safetySnapshot.data ?? const SafetyState();
                  final visibleWaves = waves
                      .where(
                        (wave) =>
                            !safety.hiddenWaveIds.contains(wave.id) &&
                            !safety.excludesUser(wave.senderId),
                      )
                      .toList();
                  final visibleConnections = connections
                      .where(
                        (connection) => !safety.excludesUser(
                          connection.getOtherUserId(user.uid),
                        ),
                      )
                      .toList();
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const _ActivityHeader(),
                            const SizedBox(height: 38),
                            if (visibleWaves.isEmpty &&
                                visibleConnections.isEmpty)
                              const _ActivityEmptyState()
                            else ...[
                              if (visibleWaves.isNotEmpty) ...[
                                _SectionHeading(
                                  label: 'Waiting for you',
                                  detail: _countLabel(
                                    visibleWaves.length,
                                    'wave',
                                  ),
                                ),
                                const SizedBox(height: 15),
                                ..._withDividers(
                                  visibleWaves.map(
                                    (wave) => _IncomingWaveEntry(
                                      wave: wave,
                                      onAccept: () =>
                                          _acceptWave(context, wave),
                                      onHide: () => _hideWave(context, wave),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 34),
                              ],
                              if (visibleConnections.isNotEmpty) ...[
                                _SectionHeading(
                                  label: 'New connections',
                                  detail: _countLabel(
                                    visibleConnections.length,
                                    'connection',
                                  ),
                                ),
                                const SizedBox(height: 15),
                                ..._withDividers(
                                  visibleConnections.map(
                                    (connection) => _ConnectionEntry(
                                      connection: connection,
                                      currentUserId: user.uid,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              const _PrivacyNote(),
                            ],
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
      ),
    );
  }

  static String _countLabel(int count, String noun) =>
      '$count $noun${count == 1 ? '' : 's'}';

  static Iterable<Widget> _withDividers(Iterable<Widget> entries) sync* {
    var first = true;
    for (final entry in entries) {
      if (!first) {
        yield const Padding(
          padding: EdgeInsets.only(left: 65),
          child: Divider(height: 1),
        );
      }
      first = false;
      yield entry;
    }
  }

  Future<void> _acceptWave(BuildContext context, WaveRequest wave) async {
    final matchId = await WaveService.instance.acceptWave(wave.id);
    if (!context.mounted) return;
    if (matchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That wave is no longer available.')),
      );
      return;
    }
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
              'You and $name can talk now.',
              style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'There’s no rush. A simple hello is enough when it feels right.',
              style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondaryLight,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await ChatUtils.startConversationWith(context, wave.senderId);
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Start a conversation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _hideWave(BuildContext context, WaveRequest wave) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await SafetyService.instance.hideWave(user.uid, wave.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Hidden from your activity.')));
  }
}

/// Compatibility name for callers that still refer to the former screen.
@Deprecated('Use ActivityPage instead.')
class WavesPage extends ActivityPage {
  const WavesPage({super.key});
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Activity',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -1.1,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        'Small openings for friendship, in one place.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.textSecondaryLight,
          height: 1.4,
        ),
      ),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label, required this.detail});
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -.2,
        ),
      ),
      const SizedBox(width: 9),
      Text(
        detail,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondaryLight),
      ),
    ],
  );
}

class _IncomingWaveEntry extends StatelessWidget {
  const _IncomingWaveEntry({
    required this.wave,
    required this.onAccept,
    required this.onHide,
  });
  final WaveRequest wave;
  final VoidCallback onAccept;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final name = wave.senderProfile['displayName'] as String? ?? 'Someone';
    final photo = wave.senderProfile['photoUrl'] as String?;
    return _ActivityEntry(
      name: name,
      photoUrl: photo,
      title: '$name sent you a wave',
      detail: '${wave.timeAgo} · You can take your time.',
      actions: [
        OutlinedButton(onPressed: onAccept, child: const Text('Wave back')),
        TextButton(onPressed: onHide, child: const Text('Hide')),
      ],
    );
  }
}

class _ConnectionEntry extends StatelessWidget {
  const _ConnectionEntry({
    required this.connection,
    required this.currentUserId,
  });
  final MutualMatch connection;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final profile = connection.getOtherUserProfile(currentUserId);
    final name = profile['displayName'] as String? ?? 'Someone';
    return _ActivityEntry(
      name: name,
      photoUrl: profile['photoUrl'] as String?,
      connection: true,
      title: 'You and $name connected',
      detail: '${_timeAgo(connection.matchedAt)} · Your conversation is open.',
      actions: [
        TextButton.icon(
          onPressed: () => ChatUtils.startConversationWith(
            context,
            connection.getOtherUserId(currentUserId),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 17),
          label: const Text('Open conversation'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ),
      ],
    );
  }

  static String _timeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }
}

class _ActivityEntry extends StatelessWidget {
  const _ActivityEntry({
    required this.name,
    required this.photoUrl,
    required this.title,
    required this.detail,
    required this.actions,
    this.connection = false,
  });
  final String name;
  final String? photoUrl;
  final String title;
  final String detail;
  final List<Widget> actions;
  final bool connection;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActivityAvatar(name: name, photoUrl: photoUrl, connection: connection),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 11),
              Wrap(spacing: 4, runSpacing: 2, children: actions),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActivityAvatar extends StatelessWidget {
  const _ActivityAvatar({
    required this.name,
    this.photoUrl,
    this.connection = false,
  });
  final String name;
  final String? photoUrl;
  final bool connection;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl?.isNotEmpty == true;
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: connection
            ? AppColors.primaryLight
            : AppColors.surfaceVariantLight,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        backgroundColor: AppColors.surfaceVariantLight,
        backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
        child: hasPhoto
            ? null
            : Text(
                name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: AppColors.secondary,
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          'Conversations open only when a wave is returned. Your location stays private.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondaryLight,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 58),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.waving_hand_outlined,
          size: 32,
          color: AppColors.secondary,
        ),
        const SizedBox(height: 17),
        Text(
          'Nothing asking for you just yet.',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        Text(
          'When someone reaches out, or a wave becomes mutual, it will appear here.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondaryLight,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}
