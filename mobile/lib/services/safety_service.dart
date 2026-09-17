/// Private, member-owned safety state and moderation reports.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class SafetyService {
  SafetyService._();
  static final instance = SafetyService._();
  final _db = FirebaseFirestore.instance;

  Future<void> hideWave(String userId, String waveId) =>
      _update(userId, {'hiddenWaveIds': FieldValue.arrayUnion([waveId])});

  Future<void> unmatch(String userId, String otherUserId) =>
      _update(userId, {'unmatchedUserIds': FieldValue.arrayUnion([otherUserId])});

  Future<void> block(String userId, String otherUserId) => _update(userId, {
        'blockedUserIds': FieldValue.arrayUnion([otherUserId]),
        'unmatchedUserIds': FieldValue.arrayUnion([otherUserId]),
      });

  Future<void> report({
    required String reporterId,
    required String subjectId,
    required String reason,
    String? conversationId,
  }) =>
      _db.collection('reports').add({
        'reporterId': reporterId,
        'subjectId': subjectId,
        'reason': reason,
        'conversationId': conversationId,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> _update(String userId, Map<String, Object> changes) =>
      _db.collection('users').doc(userId).set({
        for (final entry in changes.entries) 'safety.${entry.key}': entry.value,
      }, SetOptions(merge: true));
}
