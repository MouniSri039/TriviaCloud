
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trivia_showdown/services/attempt_repository.dart';

void main() {
  group('Graduate concurrency and collision tests', () {
    test(
      'G01: concurrent identical submissions create one document',
      () async {
        final firestore = FakeFirebaseFirestore();

        final clientA = AttemptRepository(firestore: firestore);
        final clientB = AttemptRepository(firestore: firestore);

        const uid = 'graduate-test-user';
        const roundId = 'concurrent-round-001';
        const score = 8;

        final results = await Future.wait([
          clientA.createOnce(
            uid: uid,
            roundId: roundId,
            correctCount: score,
          ),
          clientB.createOnce(
            uid: uid,
            roundId: roundId,
            correctCount: score,
          ),
        ]);

        final snapshot = await firestore
            .collection('users')
            .doc(uid)
            .collection('attempts')
            .get();

        expect(snapshot.docs.length, 1);
        expect(snapshot.docs.single.id, roundId);
        expect(snapshot.docs.single.data()['correctCount'], score);
        expect(results.where((created) => created).length, 1);
        expect(results.where((created) => !created).length, 1);
      },
      skip: 'Fake Firestore does not reliably simulate concurrent transactions.',
    );

    test(
      'G02: same ID with a different score is rejected',
      () async {
        final firestore = FakeFirebaseFirestore();
        final clientA = AttemptRepository(firestore: firestore);
        final clientB = AttemptRepository(firestore: firestore);

        const uid = 'graduate-test-user';
        const roundId = 'collision-round-001';

        await clientA.createOnce(
          uid: uid,
          roundId: roundId,
          correctCount: 8,
        );

        await expectLater(
          clientB.createOnce(
            uid: uid,
            roundId: roundId,
            correctCount: 5,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('ATTEMPT_COLLISION'),
            ),
          ),
        );

        final snapshot = await firestore
            .collection('users')
            .doc(uid)
            .collection('attempts')
            .get();

        expect(snapshot.docs.length, 1);
        expect(snapshot.docs.single.data()['correctCount'], 8);
      },
    );
  });
}
