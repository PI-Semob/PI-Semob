import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_frontend/auth_service.dart';
import 'package:semob_frontend/homepage.dart';
import 'package:semob_frontend/login.dart';
import 'package:semob_frontend/operation_page.dart';
import 'package:semob_frontend/settings_page.dart';

const usuario = UsuarioAutenticado(
  id: 'usuario-1',
  nome: 'Usuária SEMOB',
  email: 'usuario@semob.local',
);

Future<void> abrirMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
}

Future<void> selecionar(WidgetTester tester, String titulo) async {
  await abrirMenu(tester);
  await tester.tap(find.widgetWithText(ListTile, titulo));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menu abre as quatro seções e destaca a selecionada',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        usuario: usuario,
        dashboardPage: const Center(child: Text('Conteúdo Dashboard')),
        reportsPage: const Center(child: Text('Conteúdo Relatórios')),
        verificarApi: () async => const StatusSistema(
          apiDisponivel: true,
          bancoDisponivel: true,
        ),
      ),
    ));

    expect(find.text('Conteúdo Dashboard'), findsOneWidget);
    await abrirMenu(tester);
    expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Dashboard'))
            .selected,
        isTrue);
    await tester.tap(find.widgetWithText(ListTile, 'Operação'));
    await tester.pumpAndSettle();
    expect(find.text('Importe dados do transporte'), findsOneWidget);
    final estadoOperacao = tester.state(find.byType(OperationPage));

    await selecionar(tester, 'Relatórios');
    expect(find.text('Conteúdo Relatórios'), findsOneWidget);
    await abrirMenu(tester);
    expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Relatórios'))
            .selected,
        isTrue);
    await tester.tap(find.widgetWithText(ListTile, 'Configurações'));
    await tester.pumpAndSettle();
    expect(find.text('Usuária SEMOB'), findsOneWidget);
    expect(find.text('usuario@semob.local'), findsOneWidget);

    await selecionar(tester, 'Operação');
    expect(tester.state(find.byType(OperationPage)), same(estadoOperacao));
    await selecionar(tester, 'Dashboard');
    expect(find.text('Conteúdo Dashboard'), findsOneWidget);
  });

  testWidgets('configurações mostra o status e logout volta ao login',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        usuario: usuario,
        dashboardPage: const Center(child: Text('Conteúdo Dashboard')),
        reportsPage: const Center(child: Text('Conteúdo Relatórios')),
        verificarApi: () async => const StatusSistema(
          apiDisponivel: true,
          bancoDisponivel: true,
        ),
      ),
    ));

    await selecionar(tester, 'Configurações');
    expect(find.text('Disponível'), findsOneWidget);
    expect(find.text('Conectado'), findsOneWidget);
    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Sair da conta'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sair da conta'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('configurações informa quando a API não responde',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        usuario: usuario,
        onLogout: () {},
        verificarApi: () async => throw Exception('offline'),
      ),
    ));

    await tester.pumpAndSettle();
    expect(find.text('Indisponível'), findsOneWidget);
    expect(find.text('Não verificado'), findsOneWidget);
  });
}
