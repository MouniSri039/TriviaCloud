
class TriviaQuestion {
  final String category;
  final String difficulty;
  final String question;
  final String correctAnswer;
  final List<String> options;

  const TriviaQuestion({
    required this.category,
    required this.difficulty,
    required this.question,
    required this.correctAnswer,
    required this.options,
  });
}
