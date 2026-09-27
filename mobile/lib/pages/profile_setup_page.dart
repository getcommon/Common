import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/services/profile_service.dart';
import 'package:mobile/core/widgets/avatar.dart';
import 'package:mobile/constants/interest_categories.dart';
import 'package:mobile/constants/vibe_tags.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/utils/interest_utils.dart';

class ProfileSetupPage extends StatefulWidget {
  final UserProfile profile;
  const ProfileSetupPage({super.key, required this.profile});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _customInterest;
  late Set<String> _interests;
  late Set<String> _vibeTags;
  bool _saving = false;
  String? _error;
  bool _showCustomInterestField = false;
  bool _showVibeTags = false; // Collapsible vibe tag section
  bool _showInterestPicker = false;
  File? _newProfileImage; // New image selected from gallery/camera
  String? _profileImageUrl; // Current image URL from profile

  // Interest groups begin collapsed to keep the editor calm and scannable.
  final Map<InterestCategory, bool> _expandedCategories = {
    for (var category in InterestCategory.values) category: false,
  };

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.displayName ?? '');
    _bio = TextEditingController(text: widget.profile.bio ?? '');
    _customInterest = TextEditingController();
    _interests = widget.profile.interests.toSet();
    _vibeTags = widget.profile.vibeTags.toSet();
    _profileImageUrl = widget.profile.photoUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _customInterest.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _newProfileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<String?> _uploadProfileImage(File imageFile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Create a reference to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${user.uid}.jpg');

      // Upload the file
      final uploadTask = await storageRef.putFile(imageFile);

      // Get the download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
      }
      return null;
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addCustomInterest() {
    final custom = _customInterest.text.trim();
    if (custom.isEmpty) return;

    // Normalize the interest (fuzzy matching + synonym mapping)
    final normalizedInterest = normalizeInterest(custom);

    // Check if it already exists (case-insensitive)
    final lowerNormalized = normalizedInterest.toLowerCase();
    final exists = _interests.any((i) => i.toLowerCase() == lowerNormalized);

    if (!exists) {
      setState(() {
        _interests.add(normalizedInterest);
        _customInterest.clear();
        _showCustomInterestField = false;
      });

      // Show feedback if the interest was normalized
      if (normalizedInterest != custom) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added "$normalizedInterest" (matched from "$custom")',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Show a message that interest already exists
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Interest "$normalizedInterest" already added'),
          duration: const Duration(seconds: 2),
        ),
      );
      _customInterest.clear();
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Upload new profile image if selected
      String? newPhotoUrl = _profileImageUrl;
      if (_newProfileImage != null) {
        newPhotoUrl = await _uploadProfileImage(_newProfileImage!);
      }

      final name = _name.text.trim();
      final p = UserProfile(
        uid: widget.profile.uid,
        displayName: name.isEmpty ? widget.profile.displayName : name,
        photoUrl: newPhotoUrl,
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        // Preserve legacy private fields without presenting them publicly.
        classYear: widget.profile.classYear,
        major: widget.profile.major,
        interests: _interests.toList()..sort(),
        vibeTags: _vibeTags.toList(),
        createdAt: widget.profile.createdAt,
        updatedAt: DateTime.now(),
        // Location is updated only by LocationService so its server timestamp
        // and short presence expiry cannot be overwritten by profile edits.
        location: null,
        searchRadiusKm: widget.profile.searchRadiusKm,
        hasCompletedDiscoverySetup: widget.profile.hasCompletedDiscoverySetup,
      );
      await ProfileService.instance.upsertProfile(p);

      // Update Firebase Auth profile
      final user = FirebaseAuth.instance.currentUser;
      if (name.isNotEmpty) {
        await user?.updateDisplayName(name);
      }
      if (newPhotoUrl != null && newPhotoUrl != widget.profile.photoUrl) {
        await user?.updatePhotoURL(newPhotoUrl);
      }
      await user?.reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully!')),
      );

      // Navigate back to previous screen (best practice for edit screens)
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Validate interest selection
    final validationError = validateInterestSelection(_interests.toList());
    final canSave = validationError == null;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 94,
        leading: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
            foregroundColor: colors.onSurfaceVariant,
            padding: const EdgeInsets.only(left: 16),
            alignment: Alignment.centerLeft,
          ),
          child: const Text('‹ Profile'),
        ),
        actions: [
          TextButton(
            onPressed: (!canSave || _saving) ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            Text(
              'Edit profile',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                height: 1.1,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'A few details make it easier to find your people.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                if (_newProfileImage != null)
                  CircleAvatar(
                    radius: 34,
                    backgroundImage: FileImage(_newProfileImage!),
                  )
                else
                  AppAvatar(
                    imageUrl: _profileImageUrl,
                    displayName: _name.text.isNotEmpty
                        ? _name.text
                        : widget.profile.displayName,
                    size: 68,
                  ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your photo',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: _showImageSourceDialog,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.only(top: 2, bottom: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Change photo'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 22),
            const _EditorialLabel('The essentials'),
            const SizedBox(height: 13),
            TextField(
              controller: _name,
              decoration: _editorInputDecoration(context, 'Display name'),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.onSurface),
              cursorColor: colors.primary,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 17),
            TextField(
              controller: _bio,
              decoration: _editorInputDecoration(context, 'A little about you'),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.onSurface),
              cursorColor: colors.primary,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 22),
            Row(
              children: [
                const _EditorialLabel('Into lately'),
                const Spacer(),
                Text(
                  '${_interests.length} selected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            if (_interests.length < 5)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Choose at least 5 interests from two or more categories.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),

            if (_interests.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _interests
                    .map(
                      (interest) => InputChip(
                        label: Text(interest),
                        onPressed: () =>
                            setState(() => _interests.remove(interest)),
                        selected: true,
                        selectedColor: colors.primaryContainer,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 7),
            TextButton.icon(
              icon: Icon(
                _showInterestPicker
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.add_rounded,
                size: 18,
              ),
              label: Text(
                _showInterestPicker ? 'Hide interests' : 'Add interest',
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              onPressed: () =>
                  setState(() => _showInterestPicker = !_showInterestPicker),
            ),
            if (_showInterestPicker) ...[
              const SizedBox(height: 8),
              // Categorized interest selection stays tucked away until wanted.
              ...InterestCategory.values.map((category) {
                final categoryInterests = kCategorizedInterests[category] ?? [];
                final selectedInCategory = _interests
                    .where((i) => categoryInterests.contains(i))
                    .length;
                final isExpanded = _expandedCategories[category] ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: colors.outline)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          category.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '$selectedInCategory selected',
                          style: TextStyle(
                            color: selectedInCategory > 0
                                ? AppColors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        ),
                        onTap: () {
                          setState(() {
                            _expandedCategories[category] = !isExpanded;
                          });
                        },
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final interest in categoryInterests)
                                _InterestChoiceChip(
                                  label: interest,
                                  selected: _interests.contains(interest),
                                  onSelected: (selected) => setState(() {
                                    if (selected) {
                                      _interests.add(interest);
                                    } else {
                                      _interests.remove(interest);
                                    }
                                  }),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],

            // Show custom interests that don't fit predefined categories
            if (_interests.any((interest) => !kAllInterests.contains(interest)))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.outline)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _EditorialLabel('Custom interests'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final customInterest in _interests.where(
                            (i) => !kAllInterests.contains(i),
                          ))
                            FilterChip(
                              label: Text(customInterest),
                              selected: true,
                              showCheckmark: false,
                              selectedColor: colors.primaryContainer,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                              labelStyle: TextStyle(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (selected) {
                                if (!selected) {
                                  setState(() {
                                    _interests.remove(customInterest);
                                  });
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Keep custom interests available without giving them their own card.
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add custom interest'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              onPressed: () {
                setState(() {
                  _showCustomInterestField = !_showCustomInterestField;
                });
              },
            ),
            // Custom interest input field
            if (_showCustomInterestField) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customInterest,
                      decoration: _editorInputDecoration(
                        context,
                        'Custom interest',
                        hintText: 'e.g., Ultimate Frisbee',
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: colors.onSurface),
                      cursorColor: colors.primary,
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _addCustomInterest(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _addCustomInterest,
                    tooltip: 'Add',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            const Divider(height: 1),
            const SizedBox(height: 22),

            // Optional context follows the same quiet, text-first structure
            // as interests rather than introducing a separate visual system.
            Row(
              children: [
                const _EditorialLabel('A little more context'),
                const Spacer(),
                Text(
                  _vibeTags.isEmpty
                      ? 'Optional'
                      : '${_vibeTags.length} selected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            TextButton.icon(
              icon: Icon(
                _showVibeTags
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.add_rounded,
                size: 18,
              ),
              label: Text(_showVibeTags ? 'Hide context' : 'Add context'),
              style: TextButton.styleFrom(foregroundColor: colors.primary),
              onPressed: () => setState(() => _showVibeTags = !_showVibeTags),
            ),
            if (_showVibeTags)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pick ${VibeTags.minRecommendedTags}-${VibeTags.maxRecommendedTags} tags that describe your personality and study style.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...VibeCategory.values.map((category) {
                      final tags = VibeTags.tagsByCategory[category] ?? [];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.label,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tags.map((tag) {
                                final isSelected = _vibeTags.contains(tag.id);
                                return FilterChip(
                                  label: Text(tag.displayText),
                                  selected: isSelected,
                                  showCheckmark: false,
                                  selectedColor: colors.primaryContainer,
                                  backgroundColor:
                                      colors.surfaceContainerHighest,
                                  side: BorderSide.none,
                                  shape: const StadiumBorder(),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? colors.onPrimaryContainer
                                        : colors.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _vibeTags.add(tag.id);
                                      } else {
                                        _vibeTags.remove(tag.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _editorInputDecoration(
  BuildContext context,
  String label, {
  String? hintText,
}) {
  final colors = Theme.of(context).colorScheme;
  final border = UnderlineInputBorder(
    borderSide: BorderSide(color: colors.outline),
  );
  return InputDecoration(
    filled: false,
    labelText: label,
    hintText: hintText,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
    hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: .72)),
    contentPadding: const EdgeInsets.only(bottom: 8),
    enabledBorder: border,
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
  );
}

class _EditorialLabel extends StatelessWidget {
  const _EditorialLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
    ),
  );
}

class _InterestChoiceChip extends StatelessWidget {
  const _InterestChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: colors.primaryContainer,
      backgroundColor: colors.surfaceContainerHighest,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      pressElevation: 0,
      labelStyle: TextStyle(
        color: selected ? colors.onPrimaryContainer : colors.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      onSelected: onSelected,
    );
  }
}
