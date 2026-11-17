
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/quiz_screen.dart';

class TriviaCloudApp extends StatelessWidget {
  final Stream<User?>? authStateChanges;

  const TriviaCloudApp({
    super.key,
    this.authStateChanges,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TriviaCloud',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: AuthGate(
        authStateChanges: authStateChanges,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final Stream<User?>? authStateChanges;

  const AuthGate({
    super.key,
    this.authStateChanges,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateChanges ??
          FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Unable to check your sign-in status.',
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          return QuizScreen(
            key: ValueKey(snapshot.data!.uid),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
