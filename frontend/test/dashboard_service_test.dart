import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:semob_frontend/dashboard_service.dart';

void main() {
  test('consulta opções e resumo filtrado sem buscar documentos brutos',
      () async {
    final caminhos = <Uri>[];
    final cabecalhos = <Map<String, String>>[];
    final cliente = MockClient((request) async {
      caminhos.add(request.url);
      cabecalhos.add(request.headers);
      if (request.url.path == '/dashboard/opcoes') {
        return http.Response(
          jsonEncode({
            'periodos': [
              {
                'periodo': '2026-08',
                'abrangencias': ['Mensal', 'Quinzenal'],
              },
            ],
            'periodo_padrao': '2026-08',
            'abrangencia_padrao': 'Mensal',
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'periodo': '2026-08',
          'abrangencia': 'Mensal',
          'indicadores': {
            'viagens_programadas': 1000,
            'viagens_realizadas': 980,
            'quilometragem_total': 12345.5,
            'total_passageiros': 16544,
            'dias_com_dados': 2,
          },
          'evolucao': [
            {
              'data': '2026-08-01',
              'viagens_programadas': 500,
              'viagens_realizadas': 490,
            },
          ],
          'faixas_horarias': [
            {'faixa_horaria': '06:00', 'numero_viagens': 55},
          ],
          'linhas': [
            {'linha': '01', 'numero_viagens': 75},
          ],
        }),
        200,
      );
    });
    final servico = DashboardService(
      client: cliente,
      baseUrl: 'http://localhost:8000',
      accessToken: 'token-de-teste',
    );

    final opcoes = await servico.buscarOpcoes();
    final resumo = await servico.buscarResumo(
      periodo: '2026-08',
      abrangencia: 'Mensal',
    );

    expect(opcoes.periodos.single.abrangencias, ['Mensal', 'Quinzenal']);
    expect(resumo.indicadores.totalPassageiros, 16544);
    expect(resumo.evolucao.single.viagensRealizadas, 490);
    expect(resumo.faixasHorarias.single.numeroViagens, 55);
    expect(resumo.linhas.single.linha, '01');
    expect(caminhos.map((uri) => uri.path), [
      '/dashboard/opcoes',
      '/dashboard/resumo',
    ]);
    expect(caminhos.last.queryParameters, {
      'periodo': '2026-08',
      'abrangencia': 'Mensal',
    });
    expect(cabecalhos, everyElement(containsPair('Authorization', 'Bearer token-de-teste')));
  });

  test('envia todos os filtros combinados e omite filtros globais', () async {
    final urls = <Uri>[];
    final cliente = MockClient((request) async {
      urls.add(request.url);
      return http.Response(
        jsonEncode({
          'periodo': 'Todos os períodos',
          'abrangencia': null,
          'indicadores': {
            'viagens_programadas': 10,
            'viagens_realizadas': 9,
            'quilometragem_total': 50.5,
            'total_passageiros': 100,
            'dias_com_dados': 1,
          },
          'evolucao': [],
          'faixas_horarias': [],
          'linhas': [],
        }),
        200,
      );
    });
    final servico = DashboardService(
      client: cliente,
      baseUrl: 'http://localhost:8000',
    );

    await servico.buscarResumo(
      inicio: DateTime(2026, 7, 1),
      fim: DateTime(2026, 7, 5),
      linhas: const ['01', '02'],
      diasSemana: const [1, 3],
      horaInicio: 6,
      horaFim: 9,
    );
    await servico.buscarResumo();

    expect(urls[0].toString(), contains(
      '/dashboard/resumo?inicio=2026-07-01&fim=2026-07-05&linhas=01%2C02&dias=1%2C3&hora_inicio=6&hora_fim=9',
    ));
    expect(urls[0].queryParameters, {
      'inicio': '2026-07-01',
      'fim': '2026-07-05',
      'linhas': '01,02',
      'dias': '1,3',
      'hora_inicio': '6',
      'hora_fim': '9',
    });
    expect(urls[1].path, '/dashboard/resumo');
    expect(urls[1].queryParameters, isEmpty);
  });

  test('expõe erro HTTP sem dados de servidor no dashboard', () async {
    final servico = DashboardService(
      client: MockClient((_) async => http.Response('{"detail":"falha"}', 503)),
      baseUrl: 'http://localhost:8000',
    );

    expect(
      servico.buscarOpcoes(),
      throwsA(isA<DashboardException>()),
    );
  });

  test('mantém indicador sem dados como ausente', () async {
    final servico = DashboardService(
      client: MockClient((_) async => http.Response(
          jsonEncode({
            'periodo': '2026-09',
            'abrangencia': 'Quinzenal',
            'indicadores': {
              'viagens_programadas': null,
              'viagens_realizadas': null,
              'quilometragem_total': null,
              'total_passageiros': null,
              'dias_com_dados': 0,
            },
            'evolucao': [],
            'faixas_horarias': [],
            'linhas': [],
          }),
          200)),
      baseUrl: 'http://localhost:8000',
    );

    final resumo = await servico.buscarResumo(
      periodo: '2026-09',
      abrangencia: 'Quinzenal',
    );
    expect(resumo.indicadores.totalPassageiros, isNull);
    expect(resumo.indicadores.diasComDados, 0);
  });
}
