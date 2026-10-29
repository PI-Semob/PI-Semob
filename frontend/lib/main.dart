import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'homepage.dart';
import 'login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessao = await AuthService().carregarSessao();
  runApp(MeuApp(sessao: sessao));
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key, this.sessao});

  final SessaoSalva? sessao;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEMOB — Mobilidade Urbana',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFDFE9F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF005BBB),
          brightness: Brightness.light,
        ),
      ),
      home: sessao == null
          ? const LoginPage()
          : HomePage(
              usuario: sessao!.usuario,
              accessToken: sessao!.accessToken,
            ),
    );
  }
}
