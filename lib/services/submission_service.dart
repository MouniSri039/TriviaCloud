
import 'package:cloud_firestore/cloud_firestore.dart';

import 'attempt_repository.dart';

enum SubmissionStatus {
  cloudVerified,
  permissionDenied,
  unauthenticated,
  requestError,
  saveUnknown,
  verificationUnavailable,
  collision,
}

class SubmissionResult {
  final SubmissionStatus status;
  final String message;

  const SubmissionResult({
    required this.status,
    required this.message,
  });

  bool get isVerified => status == SubmissionStatus.cloudVerified;
}

class SubmissionService {
  final AttemptRepository _repository;

  SubmissionService({AttemptRepository? repository})
      : _repository = repository ?? AttemptRepository();

  /// Submits and verifies an attempt using the SAME round ID.
  /// The caller must create roundId once when a new quiz begins.
  Future<SubmissionResult> submit({
    required String uid,
    required String roundId,
    required int correctCount,
  }) async {
    try {
      await _repository.createOnce(
        uid: uid,
        roundId: roundId,
        correctCount: correctCount,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return const SubmissionResult(
          status: SubmissionStatus.permissionDenied,
          message: 'Firestore denied permission to save this attempt.',
        );
      }

      if (error.code == 'unauthenticated') {
        return const SubmissionResult(
          status: SubmissionStatus.unauthenticated,
          message: 'Please sign in again before submitting.',
        );
      }

      if (error.code == 'resource-exhausted') {
        return const SubmissionResult(
          status: SubmissionStatus.requestError,
          message: 'Firestore quota or resource limit reached.',
        );
      }

      if (error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'unknown') {
        // The commit acknowledgement may have been lost.
        // Check the SAME attempt ID before deciding what happened.
        return _recover(
          uid: uid,
          roundId: roundId,
          correctCount: correctCount,
        );
      }

      return SubmissionResult(
        status: SubmissionStatus.requestError,
        message: error.message ?? 'The attempt could not be saved.',
      );
    } on StateError catch (error) {
      if (error.message.toString().contains('ATTEMPT_COLLISION')) {
        return const SubmissionResult(
          status: SubmissionStatus.collision,
          message: 'This attempt ID already contains different results.',
        );
      }

      return SubmissionResult(
        status: SubmissionStatus.requestError,
        message: error.message.toString(),
      );
    } catch (error) {
      return SubmissionResult(
        status: SubmissionStatus.requestError,
        message: 'Unexpected submission error: $error',
      );
    }

    // The transaction completed. Now verify against the server.
    try {
      await _repository.verifyOnServer(
        uid: uid,
        roundId: roundId,
        correctCount: correctCount,
      );

      return const SubmissionResult(
        status: SubmissionStatus.cloudVerified,
        message: 'Your attempt was saved and verified on the server.',
      );
    } catch (error) {
      return SubmissionResult(
        status: SubmissionStatus.verificationUnavailable,
        message: 'The save may have succeeded, but server verification '
            'is unavailable: $error',
      );
    }
  }

  Future<SubmissionResult> _recover({
    required String uid,
    required String roundId,
    required int correctCount,
  }) async {
    try {
      await _repository.verifyOnServer(
        uid: uid,
        roundId: roundId,
        correctCount: correctCount,
      );

      return const SubmissionResult(
        status: SubmissionStatus.cloudVerified,
        message: 'The existing attempt was found and verified.',
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return const SubmissionResult(
          status: SubmissionStatus.permissionDenied,
          message: 'Firestore denied permission during recovery.',
        );
      }

      if (error.code == 'unauthenticated') {
        return const SubmissionResult(
          status: SubmissionStatus.unauthenticated,
          message: 'Sign in again to recover this attempt.',
        );
      }

      return const SubmissionResult(
        status: SubmissionStatus.saveUnknown,
        message: 'The save outcome is unknown. Keep this attempt ID '
            'and retry recovery when the server is available.',
      );
    } catch (error) {
      return SubmissionResult(
        status: SubmissionStatus.saveUnknown,
        message: 'The save outcome is unknown: $error',
      );
    }
  }
}
