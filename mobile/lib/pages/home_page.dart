/// Discover is intentionally a single, considered public profile rather than
/// a feed of dashboard cards. It is the visual starting point for Common.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/discover_profiles.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/proximity_service.dart';
import '../services/safety_service.dart';
import '../services/wave_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onNavigateToTab});

  final void Function(int tabIndex)? onNavigateToTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSendingWave = false;
  bool _waveSent = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in to discover people nearby.'));
    }

    return StreamBuilder<UserProfile?>(
      stream: ProfileService.instance.watchProfile(user.uid),
      builder: (context, snapshot) {
        final viewer = snapshot.data;
        return Scaffold(
          body: SafeArea(
            child: viewer == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<int>(
                    stream: WaveService.instance.watchWavesSentToday(
                      viewer.uid,
                    ),
                    builder: (context, wavesSnapshot) {
                      final wavesRemaining =
                          WaveService.dailyWaveLimit -
                          (wavesSnapshot.data ?? 0);
                      return StreamBuilder<List<ProximityMatch>>(
                        stream: ProximityService.instance.watchNearbyMatches(
                          viewer,
                        ),
                        builder: (context, matchesSnapshot) {
                          return StreamBuilder<SafetyState>(
                            stream: SafetyService.instance.watchSafety(
                              viewer.uid,
                            ),
                            builder: (context, safetySnapshot) {
                              final safeMatches = (matchesSnapshot.data ?? [])
                                  .where(
                                    (match) =>
                                        !(safetySnapshot.data ??
                                                const SafetyState())
                                            .excludesUser(
                                              match.userProfile.uid,
                                            ),
                                  )
                                  .toList();
                              final profile = _discoverProfileFor(safeMatches);
                              return CustomScrollView(
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      18,
                                      24,
                                      40,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildListDelegate([
                                        const _DiscoverHeader(),
                                        const SizedBox(height: 30),
                                        if (profile != null)
                                          _PublicProfile(
                                            profile: profile,
                                            wavesRemaining: wavesRemaining
                                                .clamp(
                                                  0,
                                                  WaveService.dailyWaveLimit,
                                                )
                                                .toInt(),
                                            waveSent: _waveSent,
                                            isSending: _isSendingWave,
                                            onWave:
                                                profile.profile.uid ==
                                                        erenDiscoverProfile
                                                            .profile
                                                            .uid ||
                                                    wavesRemaining <= 0
                                                ? null
                                                : () => _sendWave(
                                                    viewer,
                                                    profile,
                                                  ),
                                          )
                                        else if (matchesSnapshot.hasError)
                                          const _DiscoverState(
                                            title:
                                                'Discover is taking a moment',
                                            message:
                                                'Check your connection, then try again.',
                                          )
                                        else if (matchesSnapshot
                                                .connectionState ==
                                            ConnectionState.waiting)
                                          const _DiscoverLoading()
                                        else
                                          const _DiscoverState(
                                            title: 'Nothing new nearby yet',
                                            message:
                                                'We’ll only introduce people when there’s meaningful common ground.',
                                          ),
                                      ]),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  DiscoverProfile? _discoverProfileFor(List<ProximityMatch>? matches) {
    if (matches?.isNotEmpty == true) {
      return DiscoverProfile.fromMatch(matches!.first);
    }
    // Eren remains a visual fixture only when developing without seeded data.
    return kDebugMode && matches != null ? erenDiscoverProfile : null;
  }

  Future<void> _sendWave(UserProfile sender, DiscoverProfile recipient) async {
    if (_isSendingWave || _waveSent) return;
    setState(() => _isSendingWave = true);

    try {
      final id = await WaveService.instance.sendWave(
        senderId: sender.uid,
        receiverId: recipient.profile.uid,
        senderProfile: {
          'displayName': sender.displayName,
          'photoUrl': sender.photoUrl,
        },
        receiverProfile: {
          'displayName': recipient.profile.displayName,
          'photoUrl': recipient.profile.photoUrl,
        },
      );

      if (!mounted) return;
      setState(() {
        _isSendingWave = false;
        _waveSent = id != null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            id == null
                ? 'You already waved to ${recipient.profile.displayName}.'
                : 'Wave sent to ${recipient.profile.displayName}.',
          ),
        ),
      );
    } on StateError {
      if (!mounted) return;
      setState(() => _isSendingWave = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You’ve used today’s waves. Try again tomorrow.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSendingWave = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That wave could not be sent. Try again.'),
        ),
      );
    }
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Discover',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Someone nearby who shares your pace.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        const _PresenceMark(),
      ],
    );
  }
}

class _PresenceMark extends StatelessWidget {
  const _PresenceMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me_outlined, size: 15, color: AppColors.secondary),
          SizedBox(width: 5),
          Text(
            'Nearby',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicProfile extends StatelessWidget {
  const _PublicProfile({
    required this.profile,
    required this.wavesRemaining,
    required this.waveSent,
    required this.isSending,
    required this.onWave,
  });

  final DiscoverProfile profile;
  final int wavesRemaining;
  final bool waveSent;
  final bool isSending;
  final VoidCallback? onWave;

  @override
  Widget build(BuildContext context) {
    final person = profile.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AspectRatio(
            aspectRatio: .83,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ProfilePhoto(profile: profile),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x660D0908)],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 17,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFCFD69F),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        profile.distanceLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          [
            person.displayName,
            if (profile.age != null) '${profile.age}',
          ].whereType<String>().join(', '),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 12),
        _SharedContext(
          label: profile.compatibilityLabel,
          interests: profile.sharedInterests,
        ),
        const SizedBox(height: 21),
        Text(
          person.bio!,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 26),
        Text(
          'A few things Eren is into',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: person.interests
              .map(
                (interest) => _InterestChip(
                  label: interest,
                  shared: profile.sharedInterests.contains(interest),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 30),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onWave,
            icon: isSending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    waveSent ? Icons.check_rounded : Icons.waving_hand_outlined,
                    size: 18,
                  ),
            label: Text(
              waveSent
                  ? 'Wave sent'
                  : wavesRemaining == 0
                  ? 'Waves used for today'
                  : 'Wave',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: waveSent
                  ? AppColors.textSecondaryLight
                  : AppColors.primary,
              side: BorderSide(
                color: waveSent ? AppColors.borderLight : AppColors.primary,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          waveSent
              ? 'A simple hello is on its way.'
              : '$wavesRemaining of ${WaveService.dailyWaveLimit} waves left today. Messaging opens only if it’s mutual.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryLight),
        ),
      ],
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.profile});

  final DiscoverProfile profile;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile.profile.photoUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Image.asset(
        'assets/images/eren_editorial_portrait.png',
        fit: BoxFit.cover,
      );
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) => Image.asset(
        'assets/images/eren_editorial_portrait.png',
        fit: BoxFit.cover,
      ),
    );
  }
}

class _DiscoverLoading extends StatelessWidget {
  const _DiscoverLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _DiscoverState extends StatelessWidget {
  const _DiscoverState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(
            Icons.explore_outlined,
            size: 38,
            color: AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedContext extends StatelessWidget {
  const _SharedContext({required this.label, required this.interests});
  final String label;
  final List<String> interests;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF4ECE6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Especially ${interests.join(', ').toLowerCase()}.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label, required this.shared});
  final String label;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: shared ? const Color(0xFFF4E3DB) : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: shared ? const Color(0xFFE8C9BB) : AppColors.borderLight,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: shared ? AppColors.primaryDark : AppColors.textSecondaryLight,
          fontWeight: shared ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}
