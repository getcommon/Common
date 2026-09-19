import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/constants/proximity_constants.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/services/profile_service.dart';

/// Search radius settings widget with Material Design 3 slider
/// Allows users to configure their proximity search radius
class SearchRadiusSettings extends StatefulWidget {
  final UserProfile profile;

  const SearchRadiusSettings({super.key, required this.profile});

  @override
  State<SearchRadiusSettings> createState() => _SearchRadiusSettingsState();
}

class _SearchRadiusSettingsState extends State<SearchRadiusSettings> {
  late double _currentRadius;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Use effective search radius (user preference or default)
    _currentRadius = widget.profile.effectiveSearchRadiusKm;
  }

  Future<void> _saveRadius(double newRadius) async {
    if (newRadius == widget.profile.searchRadiusKm) {
      // No change, skip save
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Create updated profile with new search radius
      final updatedProfile = UserProfile(
        uid: widget.profile.uid,
        displayName: widget.profile.displayName,
        photoUrl: widget.profile.photoUrl,
        bio: widget.profile.bio,
        classYear: widget.profile.classYear,
        major: widget.profile.major,
        interests: widget.profile.interests,
        vibeTags: widget.profile.vibeTags,
        createdAt: widget.profile.createdAt,
        updatedAt: DateTime.now(),
        location: widget.profile.location,
        searchRadiusKm: newRadius,
        hasCompletedDiscoverySetup: widget.profile.hasCompletedDiscoverySetup,
      );

      await ProfileService.instance.upsertProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discovery radius updated'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating radius: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.radar, color: colorScheme.primary, size: 19),
            const SizedBox(width: 8),
            Text(
              'Your nearby range',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'Under 0.5 mi',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Only people within this nearby range can appear in Discover.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _getRadiusDescription(_currentRadius),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.primary.withValues(alpha: 0.3),
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withValues(alpha: 0.2),
            valueIndicatorColor: colorScheme.primary,
            valueIndicatorTextStyle: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Slider(
            value: _currentRadius,
            min: kMinSearchRadiusKm,
            max: kMaxSearchRadiusKm,
            divisions: 4,
            label: 'Nearby',
            onChanged: _isSaving
                ? null
                : (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentRadius = value);
                  },
            onChangeEnd: _saveRadius,
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Very close',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Under 0.5 mi',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        if (_isSaving) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  String _getRadiusDescription(double radiusKm) {
    if (radiusKm <= 0.7) {
      return 'Very close by';
    } else if (radiusKm <= 1.2) {
      return 'A few blocks away';
    } else if (radiusKm <= 2.0) {
      return 'Nearby';
    } else {
      return 'At your selected limit';
    }
  }
}
