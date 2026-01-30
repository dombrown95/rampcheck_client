import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/local/local_store.dart';
import 'app/auth_gate.dart';
import 'models/session.dart';
import 'ui/screens/job_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final store = await LocalStore.open();
  runApp(MyApp(store: store));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.store});
  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RampCheck',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),

      home: AuthGate(store: store),

      routes: {
        '/jobs': (context) {
          return FutureBuilder<Session?>(
            future: store.getSession(),
            builder: (context, snapshot) {
              final session = snapshot.data;
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (session == null) {
                return AuthGate(store: store);
              }
              return JobListScreen(store: store, session: session);
            },
          );
        },
      },
    );
  }
}