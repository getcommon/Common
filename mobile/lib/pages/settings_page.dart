/// Private controls kept separate from the public-facing profile.
library;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/safety_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: StreamBuilder<SafetyState>(
        stream: SafetyService.instance.watchSafety(profile.uid),
        builder: (context, snapshot) {
          final safety = snapshot.data ?? const SafetyState();
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: [
              Text(
                'Privacy & safety',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Controls for how Common protects your space.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 34),
              const _SettingsHeading('Privacy'),
              const SizedBox(height: 10),
              const _SettingNote(
                icon: Icons.location_on_outlined,
                title: 'Location stays approximate',
                message:
                    'Others see only a broad distance band, never your coordinates or venue.',
              ),
              const SizedBox(height: 14),
              const _SettingNote(
                icon: Icons.visibility_off_outlined,
                title: 'Presence is in your hands',
                message:
                    'Discoverability pauses when Common leaves the foreground and resumes only when you choose.',
              ),
              const SizedBox(height: 34),
              const _SettingsHeading('Blocked members'),
              const SizedBox(height: 10),
              if (safety.blockedUserIds.isEmpty)
                const _SettingNote(
                  icon: Icons.shield_outlined,
                  title: 'Your space is clear',
                  message:
                      'Blocked members stay private and do not appear in Discover, Activity, or Inbox.',
                )
              else
                ...safety.blockedUserIds.map(
                  (userId) => _BlockedMember(
                    userId: profile.uid,
                    blockedUserId: userId,
                  ),
                ),
              const SizedBox(height: 38),
              const _SettingsHeading('Account'),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondaryLight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _confirmSignOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in whenever you’re ready.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Settings is pushed above AppShell. Remove it before the auth gate
      // replaces the shell, otherwise this route stays visible over login.
      navigator.pop();
      await AuthService.instance.signOut();
    }
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
  );
}

class _SettingNote extends StatelessWidget {
  const _SettingNote({
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
      Icon(icon, size: 19, color: AppColors.secondary),
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
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _BlockedMember extends StatelessWidget {
  const _BlockedMember({required this.userId, required this.blockedUserId});
  final String userId;
  final String blockedUserId;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const Icon(Icons.person_off_outlined, color: AppColors.secondary),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            'Blocked member',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: () =>
              SafetyService.instance.unblock(userId, blockedUserId),
          child: const Text('Unblock'),
        ),
      ],
    ),
  );
}
