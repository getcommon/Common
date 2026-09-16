/// Personal profile and privacy controls for Common.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/profile_service.dart';
import '../widgets/search_radius_settings.dart';
import 'profile_setup_page.dart';

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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Profile',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1.1,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileSetupPage(profile: profile),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        color: AppColors.primary,
                        tooltip: 'Edit profile',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Identity(profile: profile),
                  if ((profile.bio ?? '').isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      profile.bio!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 30),
                  const _SectionHeading('Your interests'),
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
                  const SizedBox(height: 34),
                  const _SectionHeading('Discoverability'),
                  const SizedBox(height: 12),
                  _DiscoverabilityToggle(profile: profile),
                  const SizedBox(height: 12),
                  SearchRadiusSettings(profile: profile),
                  const SizedBox(height: 34),
                  const _SectionHeading('Privacy & safety'),
                  const SizedBox(height: 12),
                  const _PrivacyNote(
                    icon: Icons.location_on_outlined,
                    title: 'Your exact location stays private',
                    message:
                        'Others only see a broad distance band—not your coordinates or venue.',
                  ),
                  const SizedBox(height: 12),
                  const _PrivacyNote(
                    icon: Icons.shield_outlined,
                    title: 'Connections start with mutual interest',
                    message: 'Messaging opens only after you both wave.',
                  ),
                  const SizedBox(height: 30),
                  OutlinedButton.icon(
                    onPressed: () => _confirmSignOut(context),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondaryLight,
                      side: const BorderSide(color: AppColors.borderLight),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in whenever you’re ready.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep me signed in'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await AuthService.instance.signOut();
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 38,
        backgroundColor: AppColors.surfaceVariantLight,
        backgroundImage: profile.photoUrl == null || profile.photoUrl!.isEmpty
            ? null
            : NetworkImage(profile.photoUrl!),
        child: profile.photoUrl == null || profile.photoUrl!.isEmpty
            ? Text(
                (profile.displayName ?? '?').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      const SizedBox(width: 15),
      Expanded(
        child: Text(
          profile.displayName ?? 'Your name',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visible ? 'You’re discoverable' : 'You’re paused',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
    );
  }

  Future<void> _setVisible(bool visible) async {
    setState(() => _saving = true);
    try {
      await LocationService.instance.setLocationVisibility(
        widget.profile.uid,
        visible,
      );
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
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: AppColors.secondary),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
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
