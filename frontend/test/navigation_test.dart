import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semob_frontend/auth_service.dart';
import 'package:semob_frontend/homepage.dart';
import 'package:semob_frontend/operation_page.dart';

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
    await tester.pumpWidget(const MaterialApp(
      home: HomePage(
        usuario: usuario,
        dashboardPage: Center(child: Text('Conteúdo Dashboard')),
        reportsPage: Center(child: Text('Conteúdo Relatórios')),
      ),
    ));

    expect(find.text('Conteúdo Dashboard'), findsOneWidget);
    await abrirMenu(tester);
    expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Dashboard'))
            .selected,
        isTrue);
    await tester.tap(find.widgetWithText(ListTile, 'Importação'));
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

    await selecionar(tester, 'Importação');
    expect(tester.state(find.byType(OperationPage)), same(estadoOperacao));
    await selecionar(tester, 'Dashboard');
    expect(find.text('Conteúdo Dashboard'), findsOneWidget);
  });
}
