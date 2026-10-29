import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ImportacaoException implements Exception {
  const ImportacaoException(this.mensagem,
      {this.inseridosParcial = 0, this.statusCode});
  final String mensagem;
  final int inseridosParcial;
  final int? statusCode;
  @override
  String toString() => mensagem;
}

class ResultadoImportacao {
  const ResultadoImportacao({required this.arquivo, required this.arquivosProcessados,
    required this.arquivosRejeitados, required this.inseridos, required this.ignorados,
    required this.rejeitados, required this.detalhes});
  final String arquivo;
  final int arquivosProcessados;
  final int arquivosRejeitados;
  final int inseridos;
  final int ignorados;
  final int rejeitados;
  final List<Map<String, dynamic>> detalhes;
  factory ResultadoImportacao.fromJson(Map<String, dynamic> json) => ResultadoImportacao(
    arquivo: json['arquivo'] as String? ?? '',
    arquivosProcessados: json['arquivos_processados'] as int? ?? 0,
    arquivosRejeitados: json['arquivos_rejeitados'] as int? ?? 0,
    inseridos: json['inseridos'] as int? ?? 0,
    ignorados: json['ignorados'] as int? ?? 0,
    rejeitados: json['rejeitados'] as int? ?? 0,
    detalhes: (json['detalhes'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList(),
  );
}

class ImportacaoService {
  ImportacaoService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(), _baseUrl = baseUrl ?? ApiConfig.baseUrl;
  final http.Client _client;
  final String _baseUrl;

  Future<ResultadoImportacao> importar({required String nome, required int tamanho,
    required Stream<List<int>> conteudo,
    void Function(String mensagem, int progresso)? onProgresso}) async {
    final pedido = http.MultipartRequest('POST', Uri.parse('$_baseUrl/relatorios/importar-zip'));
    pedido.files.add(http.MultipartFile('file', conteudo, tamanho, filename: nome));
    late http.StreamedResponse envio;
    try {
      envio = await _client.send(pedido).timeout(const Duration(minutes: 15));
    } on TimeoutException {
      throw const ImportacaoException('A importação demorou além do limite.');
    } on http.ClientException {
      throw const ImportacaoException('Não foi possível conectar ao servidor.');
    }

    if (envio.statusCode < 200 || envio.statusCode >= 300) {
      final resposta = await http.Response.fromStream(envio);
      Map<String, dynamic> corpo = {};
      try { corpo = jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>; }
      on FormatException { /* A mensagem padrão abaixo atende resposta malformada. */ }
      on TypeError { /* A mensagem padrão abaixo atende resposta malformada. */ }
      if (resposta.statusCode == 409) {
        throw const ImportacaoException('Este arquivo já foi importado no sistema!', statusCode: 409);
      }
      final detalhe = corpo['detail'];
      if (detalhe is String) throw ImportacaoException(detalhe, statusCode: resposta.statusCode);
      throw ImportacaoException('Falha na importação (HTTP ${resposta.statusCode}).', statusCode: resposta.statusCode);
    }

    Map<String, dynamic>? resultado;
    try {
      await for (final linha in utf8.decoder.bind(envio.stream)
          .transform(const LineSplitter()).timeout(const Duration(minutes: 15))) {
        if (!linha.startsWith('data:')) continue;
        final evento = jsonDecode(linha.substring(5).trim()) as Map<String, dynamic>;
        switch (evento['tipo']) {
          case 'progresso':
            onProgresso?.call(evento['mensagem'] as String? ?? 'Processando ZIP...',
              (evento['progresso'] as num? ?? 0).round().clamp(0, 100).toInt());
            break;
          case 'erro':
            final parcial = evento['resultado'] as Map<String, dynamic>?;
            throw ImportacaoException(evento['mensagem'] as String? ?? 'Falha ao importar o ZIP.',
              inseridosParcial: parcial?['inseridos'] is int ? parcial!['inseridos'] as int : 0);
          case 'concluido':
            resultado = evento['resultado'] as Map<String, dynamic>?;
            break;
        }
      }
    } on TimeoutException {
      throw const ImportacaoException('A importação demorou além do limite.');
    } on FormatException {
      throw const ImportacaoException('O servidor retornou uma resposta inválida.');
    } on TypeError {
      throw const ImportacaoException('O servidor retornou uma resposta inválida.');
    }
    if (resultado == null) throw const ImportacaoException('A conexão terminou antes de concluir a importação.');
    return ResultadoImportacao.fromJson(resultado);
  }
}
