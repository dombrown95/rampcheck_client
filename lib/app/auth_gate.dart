import 'package:flutter/material.dart';
import '../data/local/local_store.dart';
import '../models/session.dart';
import '../ui/screens/job_list_screen.dart';
import '../ui/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.store});
  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Session?>(
      future: store.getSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.data;
        if (session == null) {
          return LoginScreen(store: store);
        }

        return JobListScreen(store: store, session: session);
      },
    );
  }
}