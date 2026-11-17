
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:trivia_showdown/services/attempt_repository.dart';
import 'package:trivia_showdown/services/submission_service.dart';

// T09: Commit succeeds, but acknowledgement is lost.
class LostAcknowledgementRepository extends AttemptRepository {
  LostAcknowledgementRepository(FirebaseFirestore firestore)
      : super(firestore: firestore);

  bool acknowledgementLost = false;

  @override
  Future<bool> createOnce({
    required String uid,
    required String roundId,
    required int correctCount,
  }) async {
    final created = await super.createOnce(
      uid: uid,
      roundId: roundId,
      correctCount: correctCount,
    );

    if (!acknowledgementLost) {
      acknowledgementLost = true;
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Simulated lost acknowledgement',
      );
    }

    return created;
  }
}

// T12: Simulate an unavailable Firestore service.
class UnavailableRepository extends AttemptRepository {
  UnavailableRepository(FirebaseFirestore firestore)
      : super(firestore: firestore);

  int calls = 0;

  @override
  Future<bool> createOnce({
    required String uid,
    required String roundId,
    required int correctCount,
  }) async {
    calls++;
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'Simulated service unavailable',
    );
  }
}

// T12: Simulate a Firestore quota/resource error.
class ResourceExhaustedRepository extends AttemptRepository {
  ResourceExhaustedRepository(FirebaseFirestore firestore)
      : super(firestore: firestore);

  int calls = 0;

  @override
  Future<bool> createOnce({
    required String uid,
    required String roundId,
    required int correctCount,
  }) async {
    calls++;
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'resource-exhausted',
      message: 'Simulated resource limit',
    );
  }
}

void main() {
  test('T09: lost acknowledgement recovers without duplicate', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = LostAcknowledgementRepository(firestore);
    final service = SubmissionService(repository: repository);

    const uid = 'test-user';
    const roundId = 'same-round-123';
    const score = 7;

    final result = await service.submit(
      uid: uid,
      roundId: roundId,
      correctCount: score,
    );

    expect(result.status, SubmissionStatus.cloudVerified);

    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('attempts')
        .get();

    expect(snapshot.docs.length, 1);
    expect(snapshot.docs.single.id, roundId);
    expect(snapshot.docs.single.data()['correctCount'], score);
    expect(repository.acknowledgementLost, isTrue);
  });

  test('T12: unavailable returns unknown, never false success', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = UnavailableRepository(firestore);
    final service = SubmissionService(repository: repository);

    final result = await service.submit(
      uid: 'test-user',
      roundId: 'unavailable-round',
      correctCount: 5,
    );

    expect(result.status, SubmissionStatus.saveUnknown);
    expect(result.isVerified, isFalse);
    expect(repository.calls, 1);

    final snapshot = await firestore
        .collection('users')
        .doc('test-user')
        .collection('attempts')
        .get();

    expect(snapshot.docs, isEmpty);
  });

  test('T12: resource exhausted returns a distinct error', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = ResourceExhaustedRepository(firestore);
    final service = SubmissionService(repository: repository);

    final result = await service.submit(
      uid: 'test-user',
      roundId: 'quota-round',
      correctCount: 5,
    );

    expect(result.status, SubmissionStatus.requestError);
    expect(result.message, contains('quota or resource limit'));
    expect(result.isVerified, isFalse);
    expect(repository.calls, 1);

    final snapshot = await firestore
        .collection('users')
        .doc('test-user')
        .collection('attempts')
        .get();

    expect(snapshot.docs, isEmpty);
  });
}
