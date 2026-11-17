
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;

import '../models/trivia_question.dart';

class TriviaApiService {
  static final Uri _apiUrl = Uri.parse(
    'https://opentdb.com/api.php'
    '?amount=10&category=9&difficulty=easy&type=multiple',
  );

  final http.Client _client;
  final HtmlUnescape _htmlUnescape = HtmlUnescape();

  DateTime? _lastAttempt;

  TriviaApiService({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<TriviaQuestion>> fetchQuestions() async {
    // Keep separate requests at least five seconds apart.
    final now = DateTime.now();
    if (_lastAttempt != null) {
      final elapsed = now.difference(_lastAttempt!);
      if (elapsed < const Duration(seconds: 5)) {
        await Future.delayed(
          const Duration(seconds: 5) - elapsed,
        );
      }
    }

    _lastAttempt = DateTime.now();

    final http.Response response;

    try {
      response = await _client
          .get(_apiUrl)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw Exception('The quiz request timed out. Please try again.');
    } on http.ClientException {
      throw Exception('Network error. Check your internet connection.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Quiz server returned status ${response.statusCode}.',
      );
    }

    final Map<String, dynamic> json;

    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw Exception('The quiz server returned invalid JSON.');
    } on TypeError {
      throw Exception('The quiz response has an invalid format.');
    }

    if (json['response_code'] != 0) {
      throw Exception(
        'The quiz server returned response code '
        '${json['response_code']}.',
      );
    }

    final results = json['results'];

    if (results is! List || results.length != 10) {
      throw Exception('The server must return exactly 10 questions.');
    }

    final List<TriviaQuestion> questions = [];

    for (final item in results) {
      if (item is! Map<String, dynamic>) {
        throw Exception('A question has an invalid format.');
      }

      final category = item['category'];
      final difficulty = item['difficulty'];
      final type = item['type'];
      final rawQuestion = item['question'];
      final rawCorrect = item['correct_answer'];
      final rawIncorrect = item['incorrect_answers'];

      if (category != 'General Knowledge' ||
          difficulty != 'easy' ||
          type != 'multiple') {
        throw Exception('A question does not match the quiz settings.');
      }

      if (rawQuestion is! String ||
          rawCorrect is! String ||
          rawIncorrect is! List ||
          rawIncorrect.length != 3 ||
          rawIncorrect.any((answer) => answer is! String)) {
        throw Exception('A question is missing valid answer data.');
      }

      final question = _htmlUnescape.convert(rawQuestion).trim();
      final correctAnswer = _htmlUnescape.convert(rawCorrect).trim();

      final incorrectAnswers = rawIncorrect
          .cast<String>()
          .map((answer) => _htmlUnescape.convert(answer).trim())
          .toList();

      if (question.isEmpty ||
          correctAnswer.isEmpty ||
          incorrectAnswers.any((answer) => answer.isEmpty)) {
        throw Exception('A question or answer is empty.');
      }

      final options = [
        correctAnswer,
        ...incorrectAnswers,
      ];

      if (options.toSet().length != 4) {
        throw Exception('A question contains duplicate answer choices.');
      }

      // Shuffle once when the question is created.
      options.shuffle(Random());

      questions.add(
        TriviaQuestion(
          category: category,
          difficulty: difficulty,
          question: question,
          correctAnswer: correctAnswer,
          options: List.unmodifiable(options),
        ),
      );
    }

    return List.unmodifiable(questions);
  }

  void dispose() {
    _client.close();
  }
}
