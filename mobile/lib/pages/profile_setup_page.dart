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
        location: widget.profile.location,
        searchRadiusKm: widget.profile.searchRadiusKm,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            // Profile picture editor
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      // Show either new image, current image, or default avatar
                      if (_newProfileImage != null)
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: FileImage(_newProfileImage!),
                        )
                      else
                        AppAvatar(
                          imageUrl: _profileImageUrl,
                          displayName: _name.text.isNotEmpty
                              ? _name.text
                              : widget.profile.displayName,
                          size: 120,
                        ),
                      // Edit button overlay
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                            ),
                            onPressed: _showImageSourceDialog,
                            tooltip: 'Change profile picture',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap camera to change photo',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bio,
              decoration: const InputDecoration(labelText: 'Bio (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Interest selection header with count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select your interests',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_interests.length} selected',
                  style: TextStyle(
                    color: _interests.length >= 5
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_interests.length < 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Select at least 5 interests from 2+ categories',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),

            // Categorized interest selection
            ...InterestCategory.values.map((category) {
              final categoryInterests = kCategorizedInterests[category] ?? [];
              final selectedInCategory = _interests
                  .where((i) => categoryInterests.contains(i))
                  .length;
              final isExpanded = _expandedCategories[category] ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(category.displayName),
                      subtitle: Text(
                        '$selectedInCategory selected',
                        style: TextStyle(
                          color: selectedInCategory > 0
                              ? Colors.green
                              : Colors.grey,
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
                              FilterChip(
                                label: Text(interest),
                                selected: _interests.contains(interest),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _interests.add(interest);
                                    } else {
                                      _interests.remove(interest);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),

            // Show custom interests that don't fit predefined categories
            if (_interests.any((interest) => !kAllInterests.contains(interest)))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Custom Interests',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onSelected: (selected) {
                                if (!selected) {
                                  setState(() {
                                    _interests.remove(customInterest);
                                  });
                                }
                              },
                              onDeleted: () {
                                setState(() {
                                  _interests.remove(customInterest);
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // "Add custom interest" button
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add custom interest'),
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
                      decoration: const InputDecoration(
                        labelText: 'Custom interest',
                        hintText: 'e.g., Ultimate Frisbee',
                      ),
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
            const SizedBox(height: 24),

            // Vibe Tags Section (Optional)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Text('✨', style: TextStyle(fontSize: 24)),
                    title: const Text(
                      'Add Your Vibe (Optional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _vibeTags.isEmpty
                          ? 'Get +30% profile boost! ${_vibeTags.length} selected'
                          : '${_vibeTags.length} vibe tags selected',
                      style: TextStyle(
                        color: _vibeTags.length >= VibeTags.minRecommendedTags
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    trailing: Icon(
                      _showVibeTags
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                    onTap: () {
                      setState(() {
                        _showVibeTags = !_showVibeTags;
                      });
                    },
                  ),
                  if (_showVibeTags)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pick ${VibeTags.minRecommendedTags}-${VibeTags.maxRecommendedTags} tags that describe your personality and study style',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          ...VibeCategory.values.map((category) {
                            final tags =
                                VibeTags.tagsByCategory[category] ?? [];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        category.emoji,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        category.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: tags.map((tag) {
                                      final isSelected = _vibeTags.contains(
                                        tag.id,
                                      );
                                      return FilterChip(
                                        label: Text(tag.displayText),
                                        selected: isSelected,
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

            FilledButton(
              onPressed: (!canSave || _saving) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
