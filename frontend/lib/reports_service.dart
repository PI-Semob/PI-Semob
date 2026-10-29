import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class RelatoriosException implements Exception {
  const RelatoriosException(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

class FiltrosRelatorios {
  const FiltrosRelatorios(
      {required this.periodos,
      required this.tipos,
      required this.abrangencias});
  final List<String> periodos;
  final List<String> tipos;
  final List<String> abrangencias;
  factory FiltrosRelatorios.fromJson(Map<String, dynamic> json) {
    List<String> lista(String campo) {
      final valor = json[campo];
      if (valor is! List || valor.any((item) => item is! String)) {
        throw const FormatException('Filtros inválidos');
      }
      return valor.cast<String>();
    }

    return FiltrosRelatorios(
      periodos: lista('periodos'),
      tipos: lista('tipos'),
      abrangencias: lista('abrangencias'),
    );
  }
}

class RegistroRelatorio {
  const RegistroRelatorio(
      {required this.id,
      required this.arquivoOrigem,
      required this.categoria,
      required this.tabela,
      required this.linha,
      required this.dadosOriginais,
      required this.dadosTratados});
  final String id;
  final String arquivoOrigem;
  final String categoria;
  final int tabela;
  final int linha;
  final Map<String, dynamic> dadosOriginais;
  final Map<String, dynamic> dadosTratados;
  factory RegistroRelatorio.fromJson(Map<String, dynamic> json) {
    final originais = json['dados_originais'];
    final tratados = json['dados_tratados'];
    if (json['arquivo_origem'] is! String ||
        json['categoria'] is! String ||
        json['tabela'] is! int ||
        json['linha'] is! int ||
        originais is! Map<String, dynamic> ||
        tratados is! Map<String, dynamic>) {
      throw const FormatException('Registro inválido');
    }
    return RegistroRelatorio(
      id: json['id'] is String ? json['id'] as String : '',
      arquivoOrigem: json['arquivo_origem'] as String,
      categoria: json['categoria'] as String,
      tabela: json['tabela'] as int,
      linha: json['linha'] as int,
      dadosOriginais: originais,
      dadosTratados: tratados,
    );
  }
}

class PaginaRelatorios {
  const PaginaRelatorios(
      {required this.itens,
      required this.pagina,
      required this.limite,
      required this.total,
      required this.paginas});
  final List<RegistroRelatorio> itens;
  final int pagina;
  final int limite;
  final int total;
  final int paginas;
  factory PaginaRelatorios.fromJson(Map<String, dynamic> json) {
    final itens = json['itens'];
    if (itens is! List ||
        json['pagina'] is! int ||
        json['limite'] is! int ||
        json['total'] is! int ||
        json['paginas'] is! int) {
      throw const FormatException('Página inválida');
    }
    return PaginaRelatorios(
      itens: itens
          .map((item) => RegistroRelatorio.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
      pagina: json['pagina'] as int,
      limite: json['limite'] as int,
      total: json['total'] as int,
      paginas: json['paginas'] as int,
    );
  }
}

class ResumoRelatorios {
  const ResumoRelatorios({required this.indicadores, required this.serie});
  final Map<String, dynamic> indicadores;
  final List<Map<String, dynamic>> serie;
  factory ResumoRelatorios.fromJson(Map<String, dynamic> json) {
    final indicadores = json['indicadores'];
    final serie = json['serie'];
    if (indicadores is! Map || serie is! List) {
      throw const FormatException('Resumo gerencial inválido');
    }
    return ResumoRelatorios(
      indicadores: Map<String, dynamic>.from(indicadores),
      serie:
          serie.map((item) => Map<String, dynamic>.from(item as Map)).toList(),
    );
  }
}

class RelatoriosService {
  RelatoriosService({http.Client? client, String? baseUrl, String? accessToken})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _accessToken = accessToken;

  final http.Client _client;
  final String _baseUrl;
  final String? _accessToken;

  Map<String, String> get _cabecalhos => _accessToken == null
      ? const {}
      : {'Authorization': 'Bearer $_accessToken'};

  Future<FiltrosRelatorios> filtros() async {
    final corpo = await _get(Uri.parse('$_baseUrl/relatorios/filtros'));
    try {
      return FiltrosRelatorios.fromJson(corpo);
    } on FormatException {
      throw const RelatoriosException('Resposta inválida do servidor.');
    }
  }

  Future<PaginaRelatorios> listar(
      {int pagina = 1,
      int limite = 25,
      String? tipo,
      String? periodo,
      String? linha,
      String? abrangencia}) async {
    final parametros = <String, String>{
      'page': '$pagina',
      'limit': '$limite',
      if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
      if (periodo != null && periodo.isNotEmpty) 'periodo': periodo,
      if (linha != null && linha.trim().isNotEmpty) 'linha': linha.trim(),
      if (abrangencia != null && abrangencia.isNotEmpty)
        'abrangencia': abrangencia,
    };
    final uri =
        Uri.parse('$_baseUrl/relatorios').replace(queryParameters: parametros);
    final corpo = await _get(uri);
    try {
      return PaginaRelatorios.fromJson(corpo);
    } on FormatException {
      throw const RelatoriosException('Resposta inválida do servidor.');
    } on TypeError {
      throw const RelatoriosException('Resposta inválida do servidor.');
    }
  }

  Future<ResumoRelatorios> resumo(
      {required String granularidade,
      DateTime? inicio,
      DateTime? fim,
      String? linha}) async {
    final parametros = <String, String>{'granularidade': granularidade};
    String data(DateTime valor) =>
        '${valor.year.toString().padLeft(4, '0')}-${valor.month.toString().padLeft(2, '0')}-${valor.day.toString().padLeft(2, '0')}';
    if (inicio != null && fim != null) {
      parametros['inicio'] = data(inicio);
      parametros['fim'] = data(fim);
    }
    if (linha != null && linha.trim().isNotEmpty) {
      parametros['linha'] = linha.trim();
    }
    final uri = Uri.parse('$_baseUrl/relatorios/resumo')
        .replace(queryParameters: parametros);
    final corpo = await _get(uri);
    try {
      return ResumoRelatorios.fromJson(corpo);
    } on FormatException {
      throw const RelatoriosException('Resumo inválido do servidor.');
    } on TypeError {
      throw const RelatoriosException('Resumo inválido do servidor.');
    }
  }

  Future<Uint8List> exportarCsv(
      {String? tipo,
      String? periodo,
      String? linha,
      String? abrangencia}) async {
    final parametros = <String, String>{
      if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
      if (periodo != null && periodo.isNotEmpty) 'periodo': periodo,
      if (linha != null && linha.trim().isNotEmpty) 'linha': linha.trim(),
      if (abrangencia != null && abrangencia.isNotEmpty)
        'abrangencia': abrangencia,
    };
    final uri = Uri.parse('$_baseUrl/relatorios/exportar.csv')
        .replace(queryParameters: parametros);
    late http.Response resposta;
    try {
      resposta = await _client
          .get(uri, headers: _cabecalhos)
          .timeout(const Duration(minutes: 2));
    } on TimeoutException {
      throw const RelatoriosException('A exportação demorou além do limite.');
    } on http.ClientException {
      throw const RelatoriosException('Não foi possível conectar ao servidor.');
    }
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw RelatoriosException(_mensagemErro(resposta));
    }
    return resposta.bodyBytes;
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    late http.Response resposta;
    try {
      resposta = await _client
          .get(uri, headers: _cabecalhos)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const RelatoriosException('O servidor demorou para responder.');
    } on http.ClientException {
      throw const RelatoriosException('Não foi possível conectar ao servidor.');
    }
    Map<String, dynamic> corpo;
    try {
      corpo =
          jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw const RelatoriosException('Resposta inválida do servidor.');
    } on TypeError {
      throw const RelatoriosException('Resposta inválida do servidor.');
    }
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw RelatoriosException(_mensagemErro(resposta, corpo));
    }
    return corpo;
  }

  String _mensagemErro(http.Response resposta, [Map<String, dynamic>? corpo]) {
    if (corpo == null) {
      try {
        corpo =
            jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
      } on FormatException {
        corpo = {};
      } on TypeError {
        corpo = {};
      }
    }
    final detalhe = corpo['detail'];
    return detalhe is String
        ? detalhe
        : 'Não foi possível consultar os relatórios (HTTP ${resposta.statusCode}).';
  }
}
