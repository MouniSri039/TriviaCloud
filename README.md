TriviaCloud
A Flutter quiz app that combines live trivia questions with Firebase sign-in and verified cloud attempt storage.

I built TriviaCloud for In-Class Activity 16 – Class A. The app fetches a 10-question General Knowledge round from the Open Trivia Database, lets a signed-in user complete and review the quiz, and saves the completed attempt to that user's Cloud Firestore account.
Features
- Email/password sign-in with Firebase Authentication.
- Fetches exactly 10 easy, multiple-choice General Knowledge questions from Open Trivia Database.
- Decodes question and answer text returned as HTML entities.
- Four answer choices per question, one selection per question, answer feedback, progress, and review.
- Creates a unique round ID for each new round.
- Saves attempts under the authenticated user's Firestore path.
- Uses a Firestore transaction to create an attempt once and avoid overwriting an existing attempt.
- Verifies the saved attempt with a server-only Firestore read.
- Handles uncertain submission outcomes by reconciling the same round ID instead of generating a new ID for a retry.
- Includes automated tests for API handling, submission recovery, and collision behavior.
Technology
- Flutter and Dart
- Firebase Core
- Firebase Authentication
- Cloud Firestore
- Open Trivia Database REST API
- http
- html_unescape
- fake_cloud_firestore for selected automated tests
Class A question endpoint
https://opentdb.com/api.php?amount=10&category=9&difficulty=easy&type=multiple
The app must check the HTTP response and the Open Trivia Database response_code, then validate the response before showing a playable round. A successful HTTP response alone does not mean the question payload is valid.
Firestore attempt structure
Each completed round is stored at:
users/{authenticatedUid}/attempts/{roundId}
The Class A document contains exactly these six fields:
Field	Type / required value
schemaVersion	Integer 1
variant	String "A"
categoryId	Integer 9
questionCount	Integer 10
correctCount	Integer from 0 through 10
submittedAt	Firestore server timestamp


The round ID is created once when a new quiz round begins. A retry reuses that ID. Starting a new round creates a new ID. Existing records are not overwritten: a matching existing payload is reconciled, while a different payload for the same ID is treated as a collision.

After the transaction, the app reads the exact document from Source.server and checks the stored fields and timestamp before showing the server-verified success state.
Firebase setup
1. Create or use a Firebase project for this class activity.
2. Register the Android application using the application ID configured in this project: com.mouni.triviacloud.
3. Create a Cloud Firestore database in Native mode.
4. Enable Email/Password under Firebase Authentication.
5. Configure FlutterFire from the project root:
   dart pub global activate flutterfire_cli
   flutterfire configure
6. Make sure the generated lib/firebase_options.dart matches your own Firebase project.
7. Place the Firebase-generated google-services.json in the appropriate Android app directory. Do not commit private credentials or service-account keys.
8. Publish the project's Firestore rules to the same Firebase project.
9. Create test accounts through Firebase Authentication. Do not put passwords in source code, screenshots, or this README.
The Firebase project ID used during my development was triviacloud-6a45b. A grader should use the project configuration and access process approved by the instructor. Never publish test-user passwords.
Firestore security rules
The rules must enforce authenticated ownership, the exact six-field schema, valid Class A constants and score range, and immutable attempts. The deployed rules in the repository are the source of truth; review and publish them to your own class Firebase project before running the app.

Important: client-side rules protect ownership and data shape. They do not prove that a client-calculated score is honest. A production assessment system should calculate scores in a trusted backend.
Run locally
Prerequisites:
- Flutter SDK (development environment used: Flutter 3.47.2)
- Dart SDK (development environment used: Dart 3.13.2)
- Android Studio or VS Code
- Android emulator or Android device
- Internet connection
- Firebase project configured as described above
Clone the repository:
git clone https://github.com/MouniSri039/TriviaCloud.git
cd TriviaCloud
flutter pub get
flutter devices
flutter run
Run checks
flutter analyze
flutter test
Latest reported verification during development:
- flutter analyze: No issues found.
- flutter test: 9 passed, 1 skipped, 0 failures.
- The skipped test is the fake-Firestore concurrency test (G01). Fake Firestore did not reliably simulate concurrent transactions, so G01 is not claimed as passed.
- A fake-Firestore collision test for reusing an ID with a different score passed (G02); this is not a real-cloud concurrency test.
- The unavailable and resource-exhausted recovery tests passed using injected repository errors.
- Manual offline recovery (T08) and deployed Rules Playground checks (T10–T11) were reported as completed.
These results distinguish automated simulations from checks performed against the deployed Firebase project. Do not treat fake-Firestore tests as proof of real-cloud concurrency.
Build a release APK
flutter build apk --release
Output:
build/app/outputs/flutter-apk/app-release.apk
The release APK was built successfully and installed on an Android emulator during development. The installed package ID was com.mouni.triviacloud.
Test coverage notes
The Class A test plan covers:
- Authentication and invalid sign-in.
- The exact Open Trivia Database request and invalid API responses.
- Answer selection, scoring, feedback, and replay.
- Online submission and server verification.
- Restart/retrieval of an existing attempt.
- Offline submission and same-ID recovery.
- Lost acknowledgement reconciliation.
- Cross-user read/write denial.
- Invalid score, extra-field, and update denial.
- Unavailable and resource-exhausted error handling.
Some tests use fake_cloud_firestore to test service behavior deterministically. Those tests are useful for application logic but do not replace deployed Firestore evidence. Graduate concurrency and stale-user tests must be reported separately and only marked complete after they are actually run.
Repository
https://github.com/MouniSri039/TriviaCloud
Course: Mobile App Development
Activity: In-Class Activity 16 – Class A
Project: TriviaCloud