/// Private controls kept separate from the public-facing profile.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/safety_service.dart';
import '../services/theme_controller.dart';

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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              const _SettingsHeading('Appearance'),
              const SizedBox(height: 10),
              const _AppearanceSetting(),
              const SizedBox(height: 38),
              const _SettingsHeading('Support'),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri(scheme: 'mailto', path: 'commonask3@gmail.com'),
                ),
                icon: const Icon(Icons.mail_outline, size: 18),
                label: const Text('Email Common support'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 38),
              const _SettingsHeading('Account'),
              const SizedBox(height: 10),
              if (AuthService.instance.canAddEmailPassword)
                TextButton.icon(
                  onPressed: () => _addEmailPassword(context),
                  icon: const Icon(Icons.password_outlined, size: 18),
                  label: const Text('Add email and password'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _confirmAccountDeletion(context),
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('Delete account'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
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

  Future<void> _addEmailPassword(BuildContext context) async {
    final email = TextEditingController(
      text: AuthService.instance.currentUser?.email ?? '',
    );
    final password = TextEditingController();
    final confirmation = TextEditingController();
    String? error;
    bool saving = false;
    final linked = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add email sign-in'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This adds a password to your existing account. Use the email shown below.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              TextField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (password.text.length < 8) {
                        setDialogState(
                          () => error = 'Use at least 8 characters.',
                        );
                        return;
                      }
                      if (password.text != confirmation.text) {
                        setDialogState(() => error = 'Passwords do not match.');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await AuthService.instance.addEmailPassword(
                          email: email.text,
                          password: password.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } on AuthFlowException catch (exception) {
                        setDialogState(() => error = exception.message);
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add password'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    password.dispose();
    confirmation.dispose();
    if (linked == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email sign-in added to this account.')),
      );
    }
  }

  Future<void> _confirmAccountDeletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently removes your profile, photo, waves, connections, '
          'conversations, messages, and reports. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    try {
      await AuthService.instance.deleteAccount();
      // Account deletion signs the user out, so BootstrapGate has already
      // replaced the root with WelcomePage. Remove this pushed Settings route
      // as well; otherwise it stays on top until the member taps Back.
      navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not delete your account. Please try again.'),
        ),
      );
    }
  }
}

class _AppearanceSetting extends StatelessWidget {
  const _AppearanceSetting();

  static String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System default',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: ThemeController.instance,
    builder: (context, themeMode, child) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        themeMode == ThemeMode.dark
            ? Icons.dark_mode_outlined
            : Icons.light_mode_outlined,
        color: AppColors.secondary,
      ),
      title: Text(
        'Appearance',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        _label(themeMode),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: PopupMenuButton<ThemeMode>(
        tooltip: 'Change appearance',
        onSelected: ThemeController.instance.setThemeMode,
        itemBuilder: (context) => ThemeMode.values
            .map(
              (mode) => PopupMenuItem(
                value: mode,
                child: Row(
                  children: [
                    Icon(
                      mode == ThemeMode.dark
                          ? Icons.dark_mode_outlined
                          : mode == ThemeMode.light
                          ? Icons.light_mode_outlined
                          : Icons.brightness_auto_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(_label(mode)),
                  ],
                ),
              ),
            )
            .toList(),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.chevron_right_rounded),
        ),
      ),
    ),
  );
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
