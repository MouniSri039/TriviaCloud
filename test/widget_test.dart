
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_showdown/app.dart';

void main() {
  testWidgets('TriviaCloud login screen loads', (tester) async {
    await tester.pumpWidget(
      TriviaCloudApp(
        authStateChanges: Stream.value(null),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('TriviaCloud'), findsOneWidget);
    expect(
      find.text('Sign in and test your knowledge'),
      findsOneWidget,
    );
    expect(find.text('Sign In'), findsOneWidget);
  });
}
