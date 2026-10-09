import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:semob_frontend/auth_service.dart';
import 'package:semob_frontend/homepage.dart';
import 'package:semob_frontend/login.dart';
import 'package:semob_frontend/main.dart';

Future<void> preencherLogin(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'teste@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'senha123');
  await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Entrar'));
  await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
  await tester.pump();
}

Widget appComCliente(http.Client cliente) => MaterialApp(
      home: LoginPage(
        authService: AuthService(
          client: cliente,
          baseUrl: 'http://127.0.0.1:8000',
        ),
      ),
    );

void main() {
  testWidgets('login existente exige email e senha', (tester) async {
    await tester.pumpWidget(const MeuApp());

    expect(find.text('Acesse sua conta'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pump();

    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('credenciais válidas abrem a homepage', (tester) async {
    final cliente = MockClient((_) async => http.Response(
          jsonEncode({
            'mensagem': 'Login realizado com sucesso',
            'usuario': {
              'id': 'abc',
              'nome': 'Teste',
              'email': 'teste@example.com',
            },
          }),
          200,
        ));
    await tester.pumpWidget(appComCliente(cliente));

    await preencherLogin(tester);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('credenciais inválidas mantêm login e exibem erro',
      (tester) async {
    final cliente = MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'detail': 'E-mail ou senha inválidos'})),
          401,
          headers: {'content-type': 'application/json'},
        ));
    await tester.pumpWidget(appComCliente(cliente));

    await preencherLogin(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    expect(find.text('E-mail ou senha inválidos'), findsOneWidget);
  });

  testWidgets('servidor indisponível mantém login e exibe erro',
      (tester) async {
    final cliente =
        MockClient((_) async => throw http.ClientException('offline'));
    await tester.pumpWidget(appComCliente(cliente));

    await preencherLogin(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    expect(find.text('Não foi possível conectar ao servidor.'), findsOneWidget);
  });

  testWidgets('desabilita Entrar e mostra carregamento durante a API',
      (tester) async {
    final respostaPendente = Completer<http.Response>();
    final cliente = MockClient((_) => respostaPendente.future);
    await tester.pumpWidget(appComCliente(cliente));

    await preencherLogin(tester);

    final botao = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(botao.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);

    respostaPendente.complete(http.Response.bytes(
      utf8.encode(jsonEncode({'detail': 'E-mail ou senha inválidos'})),
      401,
      headers: {'content-type': 'application/json'},
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
