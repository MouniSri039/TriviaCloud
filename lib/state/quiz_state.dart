
import '../models/trivia_question.dart';

class QuizState {
  final List<TriviaQuestion> questions;
  final List<String?> selectedAnswers;

  int currentIndex;
  int score;
  bool isAnswered;

  QuizState({
    required this.questions,
  })  : selectedAnswers = List<String?>.filled(
          questions.length,
          null,
        ),
        currentIndex = 0,
        score = 0,
        isAnswered = false;

  TriviaQuestion get currentQuestion => questions[currentIndex];

  bool get isComplete => currentIndex >= questions.length;

  bool get canContinue => isAnswered;

  bool get hasAnswered => selectedAnswers[currentIndex] != null;

  void selectAnswer(String answer) {
    if (isAnswered || isComplete) return;

    if (!currentQuestion.options.contains(answer)) return;

    selectedAnswers[currentIndex] = answer;
    isAnswered = true;

    if (answer == currentQuestion.correctAnswer) {
      score++;
    }
  }

  void continueToNextQuestion() {
    if (!isAnswered || isComplete) return;

    currentIndex++;

    if (!isComplete) {
      isAnswered = selectedAnswers[currentIndex] != null;
    }
  }

  void reset() {
    for (var i = 0; i < selectedAnswers.length; i++) {
      selectedAnswers[i] = null;
    }

    currentIndex = 0;
    score = 0;
    isAnswered = false;
  }
}
