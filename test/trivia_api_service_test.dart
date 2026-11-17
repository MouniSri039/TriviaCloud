
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trivia_showdown/services/trivia_api_service.dart';

Map<String, dynamic> validQuestion() => {
  'category': 'General Knowledge',
  'type': 'multiple',
  'difficulty': 'easy',
  'question': 'What is 2 + 2?',
  'correct_answer': '4',
  'incorrect_answers': ['1', '2', '3'],
};

Map<String, dynamic> validPayload() => {
  'response_code': 0,
  'results': List.generate(10, (_) => validQuestion()),
};

void main() {
  group('TriviaApiService - T02 and T03', () {
    test('T02: accepts exactly 10 valid Class A questions', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(),
          'https://opentdb.com/api.php?amount=10&category=9&difficulty=easy&type=multiple');
        return http.Response(jsonEncode(validPayload()), 200);
      });

      final service = TriviaApiService(client: client);

      final questions = await service.fetchQuestions();

      expect(questions.length, 10);
      expect(questions.first.category, 'General Knowledge');
      expect(questions.first.difficulty, 'easy');
      expect(questions.first.options.length, 4);
      expect(questions.first.options.toSet().length, 4);

      service.dispose();
    });

    test('T03: rejects invalid JSON', () async {
      final service = TriviaApiService(
        client: MockClient((request) async {
          return http.Response('{invalid json', 200);
        }),
      );

      expect(
        () => service.fetchQuestions(),
        throwsA(isA<Exception>()),
      );

      service.dispose();
    });

    test('T03: rejects nonzero API response code', () async {
      final service = TriviaApiService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'response_code': 1,
              'results': [],
            }),
            200,
          );
        }),
      );

      expect(
        () => service.fetchQuestions(),
        throwsA(isA<Exception>()),
      );

      service.dispose();
    });

    test('T03: rejects nine questions', () async {
      final payload = validPayload();
      payload['results'] = List.generate(9, (_) => validQuestion());

      final service = TriviaApiService(
        client: MockClient((request) async {
          return http.Response(jsonEncode(payload), 200);
        }),
      );

      expect(
        () => service.fetchQuestions(),
        throwsA(isA<Exception>()),
      );

      service.dispose();
    });
  });
}
