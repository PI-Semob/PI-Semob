import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:semob_frontend/dashboard_page.dart';
import 'package:semob_frontend/dashboard_service.dart';

void main() {
  testWidgets('mostra indicadores reais e troca período', (tester) async {
    final consultas = <String>[];
    final cliente = MockClient((request) async {
      if (request.url.path == '/dashboard/opcoes') {
        return http.Response(
            jsonEncode({
              'periodos': [
                {
                  'periodo': '2026-07',
                  'abrangencias': ['Mensal']
                },
                {
                  'periodo': '2026-08',
                  'abrangencias': ['Mensal']
                },
              ],
              'periodo_padrao': '2026-08',
              'abrangencia_padrao': 'Mensal',
            }),
            200);
      }
      final periodo = request.url.queryParameters['periodo']!;
      consultas.add(periodo);
      return http.Response(
          jsonEncode({
            'periodo': periodo,
            'abrangencia': 'Mensal',
            'indicadores': {
              'viagens_programadas': periodo == '2026-08' ? 22 : 11,
              'viagens_realizadas': periodo == '2026-08' ? 20 : 10,
              'quilometragem_total': 120.5,
              'total_passageiros': 16544,
              'dias_com_dados': 1,
            },
            'evolucao': [
              {
                'data': '$periodo-01',
                'viagens_programadas': 22,
                'viagens_realizadas': 20
              },
            ],
            'faixas_horarias': [
              {'faixa_horaria': '06:00', 'numero_viagens': 10},
            ],
            'linhas': [
              {'linha': '01', 'numero_viagens': 8},
            ],
          }),
          200);
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DashboardPage(
            service: DashboardService(
          client: cliente,
          baseUrl: 'http://localhost:8000',
        )),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('16.544'), findsOneWidget);
    expect(find.text('Viagens realizadas'), findsWidgets);
    expect(consultas, ['2026-08']);

    await tester.tap(find.byKey(const Key('dashboard-periodo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-07').last);
    await tester.pumpAndSettle();

    expect(consultas, ['2026-08', '2026-07']);
    expect(find.text('11'), findsWidgets);
  });

  testWidgets('coleção vazia apresenta estado vazio', (tester) async {
    final cliente = MockClient((_) async => http.Response(
        jsonEncode({
          'periodos': [],
          'periodo_padrao': null,
          'abrangencia_padrao': null,
        }),
        200));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: DashboardPage(
              service: DashboardService(
        client: cliente,
        baseUrl: 'http://localhost:8000',
      ))),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhum dado'), findsOneWidget);
  });

  testWidgets('nova revisão atualiza dados e preserva filtro disponível',
      (tester) async {
    var consultasOpcoes = 0;
    final periodosConsultados = <String>[];
    final cliente = MockClient((request) async {
      if (request.url.path == '/dashboard/opcoes') {
        consultasOpcoes++;
        final periodos =
            consultasOpcoes < 3 ? ['2026-07', '2026-08'] : ['2026-09'];
        return http.Response(
            jsonEncode({
              'periodos': [
                for (final periodo in periodos)
                  {
                    'periodo': periodo,
                    'abrangencias': ['Mensal']
                  },
              ],
              'periodo_padrao': periodos.last,
              'abrangencia_padrao': 'Mensal',
            }),
            200);
      }
      final periodo = request.url.queryParameters['periodo']!;
      periodosConsultados.add(periodo);
      return http.Response(
          jsonEncode({
            'periodo': periodo,
            'abrangencia': 'Mensal',
            'indicadores': {
              'viagens_programadas': consultasOpcoes,
              'viagens_realizadas': consultasOpcoes,
              'quilometragem_total': null,
              'total_passageiros': null,
              'dias_com_dados': 1,
            },
            'evolucao': [],
            'faixas_horarias': [],
            'linhas': [],
          }),
          200);
    });
    final service = DashboardService(
      client: cliente,
      baseUrl: 'http://localhost:8000',
    );
    Widget pagina(int revision) => MaterialApp(
          home: Scaffold(
            body: DashboardPage(service: service, revision: revision),
          ),
        );

    await tester.pumpWidget(pagina(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-periodo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-07').last);
    await tester.pumpAndSettle();
    expect(periodosConsultados.last, '2026-07');

    await tester.pumpWidget(pagina(1));
    await tester.pumpAndSettle();
    expect(consultasOpcoes, 2);
    expect(periodosConsultados.last, '2026-07');
    expect(find.text('2'), findsWidgets);

    await tester.pumpWidget(pagina(2));
    await tester.pumpAndSettle();
    expect(consultasOpcoes, 3);
    expect(periodosConsultados.last, '2026-09');
    expect(find.text('2026-09'), findsOneWidget);
  });

  testWidgets('tentar novamente após falha nas opções recarrega opções',
      (tester) async {
    var consultasOpcoes = 0;
    var consultasResumo = 0;
    final cliente = MockClient((request) async {
      if (request.url.path == '/dashboard/opcoes') {
        consultasOpcoes++;
        if (consultasOpcoes == 2) {
          return http.Response(jsonEncode({'detail': 'Erro nas opções'}), 503);
        }
        return http.Response(
            jsonEncode({
              'periodos': [
                {'periodo': '2026-08', 'abrangencias': ['Mensal']}
              ],
              'periodo_padrao': '2026-08',
              'abrangencia_padrao': 'Mensal',
            }),
            200);
      }
      consultasResumo++;
      return http.Response(
          jsonEncode({
            'periodo': '2026-08',
            'abrangencia': 'Mensal',
            'indicadores': {
              'viagens_programadas': 1,
              'viagens_realizadas': 1,
              'quilometragem_total': null,
              'total_passageiros': null,
              'dias_com_dados': 1,
            },
            'evolucao': [],
            'faixas_horarias': [],
            'linhas': [],
          }),
          200);
    });
    final service = DashboardService(
      client: cliente,
      baseUrl: 'http://localhost:8000',
    );
    Widget pagina(int revision) => MaterialApp(
          home: Scaffold(
            body: DashboardPage(service: service, revision: revision),
          ),
        );

    await tester.pumpWidget(pagina(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(pagina(1));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar os dados.'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(consultasOpcoes, 3);
    expect(consultasResumo, 2);
  });
}
