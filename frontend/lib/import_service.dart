import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ImportacaoException implements Exception {
  const ImportacaoException(this.mensagem, {this.inseridosParcial = 0});

  final String mensagem;
  final int inseridosParcial;

  @override
  String toString() => mensagem;
}

class ResultadoImportacao {
  const ResultadoImportacao({
    required this.arquivo,
    required this.arquivosProcessados,
    required this.arquivosRejeitados,
    required this.inseridos,
    required this.ignorados,
    required this.rejeitados,
    required this.detalhes,
  });

  final String arquivo;
  final int arquivosProcessados;
  final int arquivosRejeitados;
  final int inseridos;
  final int ignorados;
  final int rejeitados;
  final List<Map<String, dynamic>> detalhes;

  factory ResultadoImportacao.fromJson(Map<String, dynamic> json) {
    return ResultadoImportacao(
      arquivo: json['arquivo'] as String? ?? '',
      arquivosProcessados: json['arquivos_processados'] as int? ?? 0,
      arquivosRejeitados: json['arquivos_rejeitados'] as int? ?? 0,
      inseridos: json['inseridos'] as int? ?? 0,
      ignorados: json['ignorados'] as int? ?? 0,
      rejeitados: json['rejeitados'] as int? ?? 0,
      detalhes: (json['detalhes'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}

class ImportacaoService {
  ImportacaoService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<ResultadoImportacao> importar({
    required String nome,
    required int tamanho,
    required Stream<List<int>> conteudo,
  }) async {
    final pedido = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/relatorios/importar-zip'),
    );
    pedido.files.add(http.MultipartFile(
      'file',
      conteudo,
      tamanho,
      filename: nome,
    ));

    late http.Response resposta;
    try {
      final envio =
          await _client.send(pedido).timeout(const Duration(minutes: 15));
      resposta = await http.Response.fromStream(envio)
          .timeout(const Duration(minutes: 15));
    } on TimeoutException {
      throw const ImportacaoException(
          'A importação demorou além do limite. Consulte o banco antes de reenviar.');
    } on http.ClientException {
      throw const ImportacaoException('Não foi possível conectar ao servidor.');
    }

    Map<String, dynamic> corpo;
    try {
      corpo =
          jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw const ImportacaoException(
          'O servidor retornou uma resposta inválida.');
    } on TypeError {
      throw const ImportacaoException(
          'O servidor retornou uma resposta inválida.');
    }

    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      final detalhe = corpo['detail'];
      if (detalhe is String) {
        throw ImportacaoException(detalhe);
      }
      if (detalhe is Map<String, dynamic>) {
        final mensagem = detalhe['mensagem'] as String?;
        final parcial = detalhe['resultado'] as Map<String, dynamic>?;
        if (parcial != null) {
          throw ImportacaoException(
            '${mensagem ?? 'Falha na importação'}. '
            'Inseridos: ${parcial['inseridos'] ?? 0}; '
            'ignorados: ${parcial['ignorados'] ?? 0}; '
            'rejeitados: ${parcial['rejeitados'] ?? 0}.',
            inseridosParcial:
                parcial['inseridos'] is int ? parcial['inseridos'] as int : 0,
          );
        }
        throw ImportacaoException(mensagem ?? 'Falha na importação.');
      }
      throw ImportacaoException(
          'Falha na importação (HTTP ${resposta.statusCode}).');
    }

    return ResultadoImportacao.fromJson(corpo);
  }
}
