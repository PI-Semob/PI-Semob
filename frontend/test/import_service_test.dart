import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:semob_frontend/import_service.dart';

class ClienteDeTeste extends http.BaseClient {
  ClienteDeTeste(this.statusCode, this.corpo);

  final int statusCode;
  final String corpo;
  String? caminho;
  String? envio;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    caminho = request.url.path;
    envio =
        utf8.decode(await request.finalize().toBytes(), allowMalformed: true);
    return http.StreamedResponse(Stream.value(utf8.encode(corpo)), statusCode);
  }
}

void main() {
  test('envia ZIP em multipart e interpreta contagens', () async {
    final cliente = ClienteDeTeste(
        200,
        jsonEncode({
          'arquivo': 'dados.zip',
          'arquivos_processados': 1,
          'arquivos_rejeitados': 0,
          'inseridos': 2,
          'ignorados': 1,
          'rejeitados': 0,
          'detalhes': [],
        }));
    final servico =
        ImportacaoService(client: cliente, baseUrl: 'http://localhost:8000');

    final resultado = await servico.importar(
      nome: 'dados.zip',
      tamanho: 3,
      conteudo: Stream.value([1, 2, 3]),
    );

    expect(cliente.caminho, '/relatorios/importar-zip');
    expect(cliente.envio, contains('filename="dados.zip"'));
    expect(resultado.inseridos, 2);
    expect(resultado.ignorados, 1);
  });

  test('expõe erro do servidor para ZIP inválido', () async {
    final cliente =
        ClienteDeTeste(400, jsonEncode({'detail': 'Arquivo ZIP inválido'}));
    final servico =
        ImportacaoService(client: cliente, baseUrl: 'http://localhost:8000');

    expect(
      () => servico.importar(
          nome: 'dados.zip', tamanho: 3, conteudo: Stream.value([1, 2, 3])),
      throwsA(isA<ImportacaoException>().having(
        (erro) => erro.mensagem,
        'mensagem',
        'Arquivo ZIP inválido',
      )),
    );
  });
}
