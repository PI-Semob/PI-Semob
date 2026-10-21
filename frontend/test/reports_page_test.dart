import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:semob_frontend/reports_page.dart';
import 'package:semob_frontend/reports_service.dart';

Map<String, dynamic> item(String value) => {
      'id': value,
      'arquivo_origem': 'Mensal_Linhas_202608.html',
      'categoria': 'linhas',
      'tabela': 1,
      'linha': 7,
      'dados_originais': {'Campo original': value},
      'dados_tratados': {'campo_tratado': value},
    };

Widget pageWith(http.Client client) => MaterialApp(
      home: Scaffold(
        body: ReportsPage(
          service: RelatoriosService(
            client: client,
            baseUrl: 'http://localhost:8000',
          ),
        ),
      ),
    );

void main() {
  testWidgets('exibe página atual, dados originais e navegação',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/filtros')) {
        return http.Response(
          jsonEncode({
            'periodos': ['2026-08'],
            'tipos': ['linhas'],
            'abrangencias': ['Mensal'],
          }),
          200,
        );
      }
      final currentPage = request.url.queryParameters['page'] == '2' ? 2 : 1;
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'itens': [item('valor da página $currentPage')],
          'pagina': currentPage,
          'limite': 25,
          'total': 26,
          'paginas': 2,
        })),
        200,
      );
    });

    await tester.pumpWidget(pageWith(client));
    await tester.pumpAndSettle();

    expect(find.textContaining('Página 1 de 2'), findsOneWidget);
    expect(find.textContaining('Mensal_Linhas_202608.html'), findsWidgets);
    await tester.tap(find.text('Ver detalhes'));
    await tester.pumpAndSettle();
    expect(find.text('Campo original'), findsOneWidget);
    expect(find.text('valor da página 1'), findsWidgets);

    await tester.ensureVisible(find.text('Próxima'));
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Página 2 de 2'), findsOneWidget);
    expect(find.textContaining('valor da página 2'), findsWidgets);
    expect(find.textContaining('valor da página 1'), findsNothing);
  });

  testWidgets('aplica período, tipo, abrangência e linha no servidor',
      (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/filtros')) {
        return http.Response(
          jsonEncode({
            'periodos': ['2026-08'],
            'tipos': ['linhas'],
            'abrangencias': ['Mensal'],
          }),
          200,
        );
      }
      requests.add(request.url);
      return http.Response(
        jsonEncode({
          'itens': [item(request.url.queryParameters['linha'] ?? 'sem filtro')],
          'pagina': 1,
          'limite': 25,
          'total': 1,
          'paginas': 1,
        }),
        200,
      );
    });

    await tester.pumpWidget(pageWith(client));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reports_period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('08/2026').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reports_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('linhas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reports_scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mensal').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reports_line')), '01');
    await tester.tap(find.byKey(const Key('reports_apply')));
    await tester.pumpAndSettle();

    expect(requests.last.queryParameters, {
      'page': '1',
      'limit': '25',
      'periodo': '2026-08',
      'tipo': 'linhas',
      'abrangencia': 'Mensal',
      'linha': '01',
    });
    expect(find.text('01'), findsWidgets);
  });

  testWidgets('lista cheia permite rolar até a paginação sem overflow',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/filtros')) {
        return http.Response(
          jsonEncode({
            'periodos': ['2026-08'],
            'tipos': ['linhas'],
            'abrangencias': ['Mensal'],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'itens': List.generate(25, (index) => item('registro $index')),
          'pagina': 1,
          'limite': 25,
          'total': 26,
          'paginas': 2,
        }),
        200,
      );
    });

    await tester.pumpWidget(pageWith(client));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Próxima'));
    expect(tester.getTopLeft(find.text('Próxima')).dy, lessThan(600));
  });

  testWidgets('sem resultados mostra estado vazio sem página inexistente',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/filtros')) {
        return http.Response(
          jsonEncode({
            'periodos': <String>[],
            'tipos': <String>[],
            'abrangencias': <String>[],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'itens': <Object>[],
          'pagina': 1,
          'limite': 25,
          'total': 0,
          'paginas': 0,
        }),
        200,
      );
    });

    await tester.pumpWidget(pageWith(client));
    await tester.pumpAndSettle();

    expect(
        find.text('Nenhum registro encontrado para os filtros selecionados.'),
        findsOneWidget);
    expect(find.textContaining('Página 1 de 0'), findsNothing);
  });

  testWidgets('nova revisão consulta dados importados e mantém filtro válido',
      (tester) async {
    final consultas = <Uri>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/filtros')) {
        return http.Response(
          jsonEncode({
            'periodos': ['2026-08'],
            'tipos': ['linhas'],
            'abrangencias': ['Mensal'],
          }),
          200,
        );
      }
      consultas.add(request.url);
      return http.Response(
        jsonEncode({
          'itens': [item('consulta ${consultas.length}')],
          'pagina': 1,
          'limite': 25,
          'total': 1,
          'paginas': 1,
        }),
        200,
      );
    });
    final service =
        RelatoriosService(client: client, baseUrl: 'http://localhost:8000');
    Widget build(int revision) => MaterialApp(
          home: Scaffold(
            body: ReportsPage(service: service, revision: revision),
          ),
        );

    await tester.pumpWidget(build(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reports_period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('08/2026').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reports_apply')));
    await tester.pumpAndSettle();
    expect(consultas.last.queryParameters['periodo'], '2026-08');

    await tester.pumpWidget(build(1));
    await tester.pumpAndSettle();

    expect(consultas, hasLength(3));
    expect(consultas.last.queryParameters['periodo'], '2026-08');
    expect(find.textContaining('consulta 3'), findsWidgets);
    expect(find.textContaining('consulta 2'), findsNothing);
  });

  testWidgets('avisa só no detalhe de passageiros com contagem divergente',
      (tester) async {
    Map<String, dynamic> passageiro(
            String id, String categoria, String original, int tratado) =>
        {
          'id': id,
          'arquivo_origem': '$id.html',
          'categoria': categoria,
          'tabela': 1,
          'linha': 1,
          'dados_originais': {'Total Passageiros': original},
          'dados_tratados': {'total_passageiros': tratado},
        };
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/filtros')) {
        return http.Response(
          jsonEncode({
            'periodos': <String>[],
            'tipos': ['passageiros', 'linhas'],
            'abrangencias': ['Mensal'],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'itens': [
            passageiro('divergente', 'passageiros', '16.544', 16),
            passageiro('igual', 'passageiros', '1.234', 1234),
            passageiro('outra-categoria', 'linhas', '16.544', 16),
          ],
          'pagina': 1,
          'limite': 25,
          'total': 3,
          'paginas': 1,
        }),
        200,
      );
    });

    await tester.pumpWidget(pageWith(client));
    await tester.pumpAndSettle();
    const aviso = 'A contagem tratada de passageiros difere do valor original.';
    expect(find.text(aviso), findsNothing);

    await tester.tap(find.text('Ver detalhes').at(0));
    await tester.pumpAndSettle();
    expect(find.text(aviso), findsOneWidget);
    expect(find.text('16.544'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);

    await tester.tap(find.text('Ver detalhes').at(0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver detalhes').at(1));
    await tester.tap(find.text('Ver detalhes').at(1));
    await tester.pumpAndSettle();
    expect(find.text(aviso), findsNothing);

    await tester.tap(find.text('Ver detalhes').at(1));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver detalhes').at(2));
    await tester.tap(find.text('Ver detalhes').at(2));
    await tester.pumpAndSettle();
    expect(find.text(aviso), findsNothing);
  });
}
