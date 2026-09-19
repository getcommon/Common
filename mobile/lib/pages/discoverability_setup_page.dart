import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme/app_colors.dart';
import '../models/user_profile.dart';
import '../services/location_service.dart';
import '../services/profile_service.dart';

/// An intentional, post-profile choice about nearby discovery.
/// Location permission is requested only from the primary opt-in action.
class DiscoverabilitySetupPage extends StatefulWidget {
  const DiscoverabilitySetupPage({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<DiscoverabilitySetupPage> createState() =>
      _DiscoverabilitySetupPageState();
}

class _DiscoverabilitySetupPageState extends State<DiscoverabilitySetupPage> {
  bool _working = false;
  String? _message;
  bool _canOpenSettings = false;

  Future<void> _enable() async {
    setState(() {
      _working = true;
      _message = null;
      _canOpenSettings = false;
    });
    try {
      final enabled = await LocationService.instance.setLocationVisibility(
        widget.profile.uid,
        true,
      );
      if (enabled) {
        await ProfileService.instance.completeDiscoverySetup(widget.profile.uid);
        return;
      }
      final status = await LocationService.instance.locationPermissionStatus();
      if (!mounted) return;
      setState(() {
        _canOpenSettings = status.isPermanentlyDenied || status.isRestricted;
        _message = _canOpenSettings
            ? 'Location is off for Common. You can enable it in Settings, or continue without nearby discovery.'
            : 'Location access is needed to appear in Discover. You can try again or continue without it.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'We could not turn on nearby discovery right now. You can continue and try again from Profile.';
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _continueWithoutLocation() async {
    setState(() => _working = true);
    try {
      await LocationService.instance.setLocationVisibility(widget.profile.uid, false);
      await ProfileService.instance.completeDiscoverySetup(widget.profile.uid);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openSettings() async {
    await LocationService.instance.openLocationSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4E3DB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.near_me_outlined, color: AppColors.primary),
              ),
              const Spacer(flex: 2),
              Text(
                'Nearby, on your terms.',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Turn on discoverability to meet people with meaningful common ground nearby. You can pause it anytime.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondaryLight,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              const _PrivacyPoint(
                icon: Icons.location_on_outlined,
                text: 'Your exact location and venue are never shown.',
              ),
              const _PrivacyPoint(
                icon: Icons.radar_outlined,
                text: 'You begin with a nearby range of under 0.5 mi.',
              ),
              const _PrivacyPoint(
                icon: Icons.visibility_off_outlined,
                text: 'Leaving Common pauses discovery until you choose to enable it again.',
              ),
              const Spacer(flex: 3),
              if (_message != null) ...[
                Text(_message!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryLight, height: 1.35)),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _working ? null : _enable,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _working
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Turn on nearby discovery'),
              ),
              if (_canOpenSettings)
                TextButton(
                  onPressed: _working ? null : _openSettings,
                  child: const Text('Open device settings'),
                ),
              Center(
                child: TextButton(
                  onPressed: _working ? null : _continueWithoutLocation,
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.secondary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35))),
      ],
    ),
  );
}
