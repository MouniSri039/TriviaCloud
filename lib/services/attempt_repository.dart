
import 'package:cloud_firestore/cloud_firestore.dart';

class AttemptRepository {
  final FirebaseFirestore _firestore;

  AttemptRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
String createRoundId(String uid) {
  if (uid.isEmpty) {
    throw ArgumentError('User ID is required.');
  }

  return _firestore
      .collection('users')
      .doc(uid)
      .collection('attempts')
      .doc()
      .id;
}
  DocumentReference<Map<String, dynamic>> _attemptRef({
    required String uid,
    required String roundId,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('attempts')
        .doc(roundId);
  }

  Map<String, dynamic> _expectedFields({
    required int correctCount,
  }) {
    return {
      'schemaVersion': 1,
      'variant': 'A',
      'categoryId': 9,
      'questionCount': 10,
      'correctCount': correctCount,
    };
  }

  /// Creates an attempt once, or reuses it if the existing
  /// document contains the same five fixed values.
  Future<bool> createOnce({
    required String uid,
    required String roundId,
    required int correctCount,
  }) async {
    if (uid.isEmpty || roundId.isEmpty) {
      throw ArgumentError('User ID and round ID are required.');
    }

    if (correctCount < 0 || correctCount > 10) {
      throw ArgumentError.value(
        correctCount,
        'correctCount',
        'Score must be between 0 and 10.',
      );
    }

    final ref = _attemptRef(uid: uid, roundId: roundId);
    final expected = _expectedFields(correctCount: correctCount);

    return _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(ref);

      if (snapshot.exists) {
        final existing = snapshot.data();

        if (existing == null) {
          throw StateError('Existing attempt has no data.');
        }

        final matches = expected.entries.every(
          (entry) => existing[entry.key] == entry.value,
        );

        if (!matches) {
          throw StateError(
            'ATTEMPT_COLLISION: This attempt ID already contains '
            'different quiz results.',
          );
        }

        // Matching attempt already exists. Never overwrite it.
        return false;
      }

      transaction.set(ref, {
        ...expected,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  /// Verifies the attempt using the Firestore server,
  /// not the local cache.
  Future<void> verifyOnServer({
    required String uid,
    required String roundId,
    required int correctCount,
  }) async {
    final ref = _attemptRef(uid: uid, roundId: roundId);
    final expected = _expectedFields(correctCount: correctCount);

    final snapshot = await ref.get(
      const GetOptions(source: Source.server),
    );

    if (!snapshot.exists) {
      throw StateError('VERIFICATION_UNAVAILABLE: Attempt not found.');
    }

    if (snapshot.metadata.hasPendingWrites) {
      throw StateError(
        'VERIFICATION_UNAVAILABLE: Attempt still has pending writes.',
      );
    }

    final data = snapshot.data();

    if (data == null || data.length != 6) {
      throw StateError(
        'VERIFICATION_UNAVAILABLE: Attempt has an invalid schema.',
      );
    }

    final matches = expected.entries.every(
      (entry) => data[entry.key] == entry.value,
    );

    if (!matches || data['submittedAt'] is! Timestamp) {
      throw StateError(
        'VERIFICATION_UNAVAILABLE: Saved attempt does not match.',
      );
    }
  }
}
