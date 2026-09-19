/// Personal profile and privacy controls for Common.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/user_profile.dart';
import '../services/location_service.dart';
import '../services/profile_service.dart';
import '../widgets/search_radius_settings.dart';
import 'profile_setup_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in to see your profile.'));
    }

    return StreamBuilder<UserProfile?>(
      stream: ProfileService.instance.watchProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final profile = snapshot.data;
        if (profile == null) {
          return const _ProfileState(message: 'Your profile is not ready yet.');
        }
        return _ProfileContent(profile: profile);
      },
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ProfileHeader(profile: profile),
                  const SizedBox(height: 22),
                  const Divider(height: 1),
                  const SizedBox(height: 22),
                  const _SectionHeading('A little about me'),
                  const SizedBox(height: 7),
                  if ((profile.bio ?? '').isNotEmpty) ...[
                    Text(
                      profile.bio!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ] else ...[
                    const _PlainText(
                      'Add a few words about what you enjoy and what you’re hoping to find.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 22),
                  const _SectionHeading('Into lately'),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: profile.interests.isEmpty
                        ? [
                            const _PlainText(
                              'Add a few interests to make discovery more personal.',
                            ),
                          ]
                        : profile.interests
                              .map((interest) => _InterestChip(interest))
                              .toList(),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 15),
                  _LocationSummary(profile: profile),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final visible = profile.location?.isVisible ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'COMMON GROUNDS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondaryLight,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(profile: profile),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
              color: AppColors.textPrimaryLight,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariantLight,
              ),
              tooltip: 'Settings',
            ),
          ],
        ),
        const SizedBox(height: 22),
        CircleAvatar(
          radius: 46,
          backgroundColor: AppColors.surfaceVariantLight,
          backgroundImage: profile.photoUrl == null || profile.photoUrl!.isEmpty
              ? null
              : NetworkImage(profile.photoUrl!),
          child: profile.photoUrl == null || profile.photoUrl!.isEmpty
              ? Text(
                  (profile.displayName ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                profile.displayName ?? 'Your name',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 30,
                  height: 1.08,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileSetupPage(profile: profile),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: const Text('Edit profile'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          visible ? 'Nearby · discoverable' : 'Nearby · discovery paused',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryLight),
        ),
      ],
    );
  }
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final visible = profile.location?.isVisible ?? false;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location & discovery',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose whether you appear nearby and how close someone needs to be.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _DiscoverabilityToggle(profile: profile),
                  const SizedBox(height: 22),
                  SearchRadiusSettings(profile: profile),
                ],
              ),
            ),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visible ? 'Discoverable nearby' : 'Discovery is paused',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    visible
                        ? 'Your nearby range is set in a privacy-safe way.'
                        : 'Tap to choose when you appear in Discover.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverabilityToggle extends StatefulWidget {
  const _DiscoverabilityToggle({required this.profile});
  final UserProfile profile;

  @override
  State<_DiscoverabilityToggle> createState() => _DiscoverabilityToggleState();
}

class _DiscoverabilityToggleState extends State<_DiscoverabilityToggle> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final visible = widget.profile.location?.isVisible ?? false;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visible ? 'Discoverable nearby' : 'Discovery is paused',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    visible
                        ? 'People with meaningful common ground can find you nearby.'
                        : 'You won’t appear in Discover until you turn this back on.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(value: visible, onChanged: _saving ? null : _setVisible),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _setVisible(bool visible) async {
    setState(() => _saving = true);
    try {
      final updated = await LocationService.instance.setLocationVisibility(
        widget.profile.uid,
        visible,
      );
      if (!updated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location access is needed to become discoverable.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondaryLight,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
    ),
  );
}

class _InterestChip extends StatelessWidget {
  const _InterestChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF4E3DB),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.primaryDark,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _PlainText extends StatelessWidget {
  const _PlainText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryLight),
  );
}

class _ProfileState extends StatelessWidget {
  const _ProfileState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(message)));
}
