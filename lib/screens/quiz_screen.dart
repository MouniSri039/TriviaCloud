
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/trivia_question.dart';
import '../services/attempt_repository.dart';
import '../services/submission_service.dart';
import '../services/trivia_api_service.dart';
import '../state/quiz_state.dart';
import 'answer_review_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final TriviaApiService _apiService = TriviaApiService();
  final AttemptRepository _attemptRepository = AttemptRepository();
  final SubmissionService _submissionService = SubmissionService();

  QuizState? _quizState;

  String? _userId;
  String? _roundId;
  String? _errorMessage;

  SubmissionResult? _submissionResult;

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    if (_isSubmitting ||
        (_submissionResult != null &&
            _submissionResult!.status !=
                SubmissionStatus.cloudVerified)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _quizState = null;
      _submissionResult = null;
      _roundId = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Please sign in before starting a quiz.');
      }

      final questions = await _apiService.fetchQuestions();

      if (!mounted) return;

      final newRoundId =
          _attemptRepository.createRoundId(user.uid);

      setState(() {
        _quizState = QuizState(questions: questions);
        _userId = user.uid;
        _roundId = newRoundId;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _selectAnswer(String answer) {
    if (_quizState == null || _quizState!.isComplete) return;

    setState(() {
      _quizState!.selectAnswer(answer);
    });
  }

  void _continueQuiz() {
    if (_quizState == null || !_quizState!.canContinue) return;

    setState(() {
      _quizState!.continueToNextQuestion();
    });
  }

  Future<void> _submitQuiz() async {
    final quiz = _quizState;
    final uid = _userId;
    final roundId = _roundId;

    if (quiz == null ||
        uid == null ||
        roundId == null ||
        !quiz.isComplete ||
        _isSubmitting ||
        _submissionResult?.status ==
            SubmissionStatus.cloudVerified) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid != uid) {
      setState(() {
        _submissionResult = const SubmissionResult(
          status: SubmissionStatus.unauthenticated,
          message: 'Your sign-in session has changed. Please sign in again.',
        );
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionResult = null;
    });

    final result = await _submissionService.submit(
      uid: uid,
      roundId: roundId,
      correctCount: quiz.score,
    );

    if (!mounted) return;

    // Ignore a response belonging to an old user or old round.
    final latestUser = FirebaseAuth.instance.currentUser;

    if (latestUser == null ||
        latestUser.uid != uid ||
        _roundId != roundId) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _submissionResult = result;
    });
  }

  Color _optionColor(String option, TriviaQuestion question) {
    final selected =
        _quizState!.selectedAnswers[_quizState!.currentIndex];

    if (!_quizState!.isAnswered) {
      return Colors.white;
    }

    if (option == question.correctAnswer) {
      return Colors.green.shade100;
    }

    if (option == selected) {
      return Colors.red.shade100;
    }

    return Colors.white;
  }

  IconData? _optionIcon(String option, TriviaQuestion question) {
    if (!_quizState!.isAnswered) return null;

    final selected =
        _quizState!.selectedAnswers[_quizState!.currentIndex];

    if (option == question.correctAnswer) {
      return Icons.check_circle;
    }

    if (option == selected) {
      return Icons.cancel;
    }

    return null;
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Loading your questions...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load the quiz',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadQuiz,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionStatus() {
    final result = _submissionResult;

    if (result == null && !_isSubmitting) {
      return const SizedBox.shrink();
    }

    if (_isSubmitting) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Submitting and verifying your attempt...',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final verified =
        result!.status == SubmissionStatus.cloudVerified;

    return Card(
      color: verified
          ? Colors.green.shade50
          : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              verified ? Icons.verified : Icons.warning_amber,
              color: verified ? Colors.green : Colors.deepOrange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result.message,
                style: TextStyle(
                  color: verified
                      ? Colors.green.shade900
                      : Colors.deepOrange.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final quiz = _quizState!;
    final verified =
        _submissionResult?.status ==
            SubmissionStatus.cloudVerified;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events,
              size: 90,
              color: Colors.amber,
            ),
            const SizedBox(height: 20),
            const Text(
              'Quiz Completed!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${quiz.score} / 10',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Your General Knowledge score'),
            const SizedBox(height: 20),

            _buildSubmissionStatus(),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting || verified
                    ? null
                    : _submitQuiz,
                icon: Icon(
                  verified ? Icons.verified : Icons.cloud_upload,
                ),
                label: Text(
                  verified
                      ? 'Attempt Verified'
                      : _submissionResult == null
                          ? 'Submit Quiz'
                          : 'Retry Submission',
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnswerReviewScreen(
                        questions: quiz.questions,
                        selectedAnswers: quiz.selectedAnswers,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.rate_review),
                label: const Text('Review Answers'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: verified ? _loadQuiz : null,
                icon: const Icon(Icons.replay),
                label: const Text('Play Again'),
              ),
            ),

            if (!verified) ...[
              const SizedBox(height: 8),
              const Text(
                'Verify your submission before starting another round.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    final quiz = _quizState!;

    if (quiz.isComplete) {
      return _buildResults();
    }

    final question = quiz.currentQuestion;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'General Knowledge',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Question ${quiz.currentIndex + 1} of 10',
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: (quiz.currentIndex + 1) / 10,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 32),
          Text(
            'Question ${quiz.currentIndex + 1}',
            style: const TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 28),
          ...question.options.map((option) {
            final icon = _optionIcon(option, question);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _optionColor(option, question),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.centerLeft,
                    side: const BorderSide(
                      color: Colors.deepPurple,
                    ),
                  ),
                  onPressed: quiz.isAnswered
                      ? null
                      : () => _selectAnswer(option),
                  child: Row(
                    children: [
                      Expanded(child: Text(option)),
                      if (icon != null)
                        Icon(
                          icon,
                          color: option == question.correctAnswer
                              ? Colors.green
                              : Colors.red,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (quiz.isAnswered) ...[
            const SizedBox(height: 8),
            Text(
              quiz.selectedAnswers[quiz.currentIndex] ==
                      question.correctAnswer
                  ? 'Correct! Well done.'
                  : 'Incorrect. The correct answer is: '
                      '${question.correctAnswer}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: quiz.selectedAnswers[quiz.currentIndex] ==
                        question.correctAnswer
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: quiz.canContinue ? _continueQuiz : null,
              child: Text(
                quiz.currentIndex == 9
                    ? 'Finish Quiz'
                    : 'Continue',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text('TriviaCloud'),
  centerTitle: true,
  actions: [
    IconButton(
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout),
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
      },
    ),
  ],
),
      body: _isLoading
          ? _buildLoading()
          : _errorMessage != null
              ? _buildError()
              : _buildQuiz(),
    );
  }
}
