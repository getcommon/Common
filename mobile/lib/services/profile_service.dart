import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

class ProfileService {
  ProfileService._();
  static final instance = ProfileService._();

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Future<UserProfile?> getProfile(String uid) async {
    try {
      final snap = await _doc(uid).get();
      if (!snap.exists) return null;
      return UserProfile.fromMap(snap.data()!);
    } catch (e) {
      // Log the error for debugging
      debugPrint('Error loading profile for uid $uid: $e');
      rethrow;
    }
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _doc(uid).snapshots().map((s) {
      if (s.data() == null) return null;
      try {
        return UserProfile.fromMap(s.data()!);
      } catch (e) {
        // Log the error for debugging
        debugPrint('Error parsing profile data for uid $uid: $e');
        // Return null to indicate profile couldn't be loaded
        return null;
      }
    });
  }

  Future<void> upsertProfile(UserProfile p) async {
    final now = DateTime.now();
    final payload = p.toMap()
      ..['updatedAt'] = now.millisecondsSinceEpoch
      ..putIfAbsent('createdAt', () => now.millisecondsSinceEpoch);
    await _doc(p.uid).set(payload, SetOptions(merge: true));
  }

  /// Records that a member has made an intentional discoverability choice.
  /// This is separate from visibility, since choosing "Not now" is valid.
  Future<void> completeDiscoverySetup(String uid) => _doc(uid).set({
    'hasCompletedDiscoverySetup': true,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  }, SetOptions(merge: true));

  Future<void> ensureDoc(
    String uid, {
    String? displayName,
    String? photoUrl,
  }) async {
    final ref = _doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final now = DateTime.now();
      await ref.set({
        'uid': uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'bio': null,
        'classYear': null,
        'major': null,
        'interests': <String>[],
        'hasCompletedDiscoverySetup': false,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
    }
  }
}
