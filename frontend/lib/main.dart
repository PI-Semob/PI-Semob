import 'package:flutter/material.dart';
import 'login.dart';

void main() {
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEMOB — Mobilidade Urbana',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Color(0xFFDFE9F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF005BBB),
          brightness: Brightness.light,
        ),
      ),
      home: const LoginPage(),
    );
  }
}
