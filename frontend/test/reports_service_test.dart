import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:semob_frontend/reports_service.dart';

void main() {
  test('consulta apenas a página e os filtros pedidos ao backend', () async {
    Uri? recebida;
    final service = RelatoriosService(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        recebida = request.url;
        return http.Response(
          jsonEncode({
            'itens': [
              {
                'id': 'abc',
                'arquivo_origem': 'Mensal_Linhas_202608.html',
                'categoria': 'linhas',
                'tabela': 1,
                'linha': 7,
                'dados_originais': {'Linha': '01', 'Viagens': '1.234'},
                'dados_tratados': {'linha': '01', 'viagens': 1234},
              },
            ],
            'pagina': 2,
            'limite': 25,
            'total': 51,
            'paginas': 3,
          }),
          200,
        );
      }),
    );

    final page = await service.listar(
      pagina: 2,
      limite: 25,
      tipo: 'linhas',
      periodo: '2026-08',
      linha: '01',
      abrangencia: 'Mensal',
    );

    expect(recebida?.path, '/relatorios');
    expect(recebida?.queryParameters, {
      'page': '2',
      'limit': '25',
      'tipo': 'linhas',
      'periodo': '2026-08',
      'linha': '01',
      'abrangencia': 'Mensal',
    });
    expect(page.itens, hasLength(1));
    expect(page.itens.single.dadosOriginais['Viagens'], '1.234');
    expect(page.itens.single.dadosTratados['viagens'], 1234);
    expect(page.total, 51);
    expect(page.paginas, 3);
  });

  test('carrega filtros reais disponíveis no banco', () async {
    final service = RelatoriosService(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        expect(request.url.path, '/relatorios/filtros');
        return http.Response(
          jsonEncode({
            'periodos': ['2026-08'],
            'tipos': ['linhas', 'passageiros'],
            'abrangencias': ['Mensal', 'Quinzenal'],
          }),
          200,
        );
      }),
    );

    final filters = await service.filtros();

    expect(filters.periodos, ['2026-08']);
    expect(filters.tipos, ['linhas', 'passageiros']);
    expect(filters.abrangencias, ['Mensal', 'Quinzenal']);
  });

  test('mostra falha da API sem interpretar resposta como lista vazia',
      () async {
    final service = RelatoriosService(
      baseUrl: 'http://localhost:8000',
      client: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({'detail': 'Banco de dados indisponível'})),
            503,
          )),
    );

    await expectLater(
      service.listar(),
      throwsA(isA<RelatoriosException>().having(
        (error) => error.mensagem,
        'mensagem',
        'Banco de dados indisponível',
      )),
    );
  });
}
