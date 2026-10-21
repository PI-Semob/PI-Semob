import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class DashboardException implements Exception {
  const DashboardException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

class PeriodoOpcao {
  const PeriodoOpcao(this.periodo, this.abrangencias);

  final String periodo;
  final List<String> abrangencias;
}

class DashboardOpcoes {
  const DashboardOpcoes({
    required this.periodos,
    required this.periodoPadrao,
    required this.abrangenciaPadrao,
  });

  final List<PeriodoOpcao> periodos;
  final String? periodoPadrao;
  final String? abrangenciaPadrao;
}

class DashboardIndicadores {
  const DashboardIndicadores({
    required this.viagensProgramadas,
    required this.viagensRealizadas,
    required this.quilometragemTotal,
    required this.totalPassageiros,
    required this.diasComDados,
  });

  final int? viagensProgramadas;
  final int? viagensRealizadas;
  final double? quilometragemTotal;
  final int? totalPassageiros;
  final int diasComDados;
}

class EvolucaoPonto {
  const EvolucaoPonto({
    required this.data,
    required this.viagensProgramadas,
    required this.viagensRealizadas,
  });

  final String data;
  final int viagensProgramadas;
  final int viagensRealizadas;
}

class FaixaHorariaResumo {
  const FaixaHorariaResumo(this.faixaHoraria, this.numeroViagens);

  final String faixaHoraria;
  final int numeroViagens;
}

class LinhaResumo {
  const LinhaResumo(this.linha, this.numeroViagens);

  final String linha;
  final int numeroViagens;
}

class DashboardResumo {
  const DashboardResumo({
    required this.periodo,
    required this.abrangencia,
    required this.indicadores,
    required this.evolucao,
    required this.faixasHorarias,
    required this.linhas,
  });

  final String periodo;
  final String abrangencia;
  final DashboardIndicadores indicadores;
  final List<EvolucaoPonto> evolucao;
  final List<FaixaHorariaResumo> faixasHorarias;
  final List<LinhaResumo> linhas;
}

class DashboardService {
  DashboardService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<DashboardOpcoes> buscarOpcoes() async {
    final corpo = await _get('/dashboard/opcoes');
    try {
      final periodos = _lista(corpo['periodos']).map((item) {
        final mapa = _mapa(item);
        return PeriodoOpcao(
          _texto(mapa['periodo']),
          _lista(mapa['abrangencias']).map(_texto).toList(),
        );
      }).toList();
      return DashboardOpcoes(
        periodos: periodos,
        periodoPadrao: corpo['periodo_padrao'] as String?,
        abrangenciaPadrao: corpo['abrangencia_padrao'] as String?,
      );
    } on TypeError {
      throw const DashboardException('Resposta inválida do servidor.');
    }
  }

  Future<DashboardResumo> buscarResumo({
    required String periodo,
    required String abrangencia,
  }) async {
    final corpo = await _get('/dashboard/resumo', {
      'periodo': periodo,
      'abrangencia': abrangencia,
    });
    try {
      final indicadores = _mapa(corpo['indicadores']);
      return DashboardResumo(
        periodo: _texto(corpo['periodo']),
        abrangencia: _texto(corpo['abrangencia']),
        indicadores: DashboardIndicadores(
          viagensProgramadas:
              _numeroOpcional(indicadores['viagens_programadas'])?.toInt(),
          viagensRealizadas:
              _numeroOpcional(indicadores['viagens_realizadas'])?.toInt(),
          quilometragemTotal:
              _numeroOpcional(indicadores['quilometragem_total'])?.toDouble(),
          totalPassageiros:
              _numeroOpcional(indicadores['total_passageiros'])?.toInt(),
          diasComDados: _numero(indicadores['dias_com_dados']).toInt(),
        ),
        evolucao: _lista(corpo['evolucao']).map((item) {
          final ponto = _mapa(item);
          return EvolucaoPonto(
            data: _texto(ponto['data']),
            viagensProgramadas: _numero(ponto['viagens_programadas']).toInt(),
            viagensRealizadas: _numero(ponto['viagens_realizadas']).toInt(),
          );
        }).toList(),
        faixasHorarias: _lista(corpo['faixas_horarias']).map((item) {
          final faixa = _mapa(item);
          return FaixaHorariaResumo(
            _texto(faixa['faixa_horaria']),
            _numero(faixa['numero_viagens']).toInt(),
          );
        }).toList(),
        linhas: _lista(corpo['linhas']).map((item) {
          final linha = _mapa(item);
          return LinhaResumo(
            _texto(linha['linha']),
            _numero(linha['numero_viagens']).toInt(),
          );
        }).toList(),
      );
    } on TypeError {
      throw const DashboardException('Resposta inválida do servidor.');
    }
  }

  Future<Map<String, dynamic>> _get(
    String caminho, [
    Map<String, String>? parametros,
  ]) async {
    try {
      final uri =
          Uri.parse('$_baseUrl$caminho').replace(queryParameters: parametros);
      final resposta =
          await _client.get(uri).timeout(const Duration(seconds: 20));
      if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
        throw const DashboardException('Não foi possível carregar os dados.');
      }
      return _mapa(jsonDecode(utf8.decode(resposta.bodyBytes)));
    } on DashboardException {
      rethrow;
    } on TimeoutException {
      throw const DashboardException('O servidor demorou para responder.');
    } on http.ClientException {
      throw const DashboardException('Não foi possível conectar ao servidor.');
    } on FormatException {
      throw const DashboardException('Resposta inválida do servidor.');
    } on TypeError {
      throw const DashboardException('Resposta inválida do servidor.');
    }
  }

  static Map<String, dynamic> _mapa(Object? valor) {
    if (valor is Map<String, dynamic>) return valor;
    throw const DashboardException('Resposta inválida do servidor.');
  }

  static List<dynamic> _lista(Object? valor) {
    if (valor is List) return valor;
    throw const DashboardException('Resposta inválida do servidor.');
  }

  static String _texto(Object? valor) {
    if (valor is String) return valor;
    throw const DashboardException('Resposta inválida do servidor.');
  }

  static num _numero(Object? valor) {
    if (valor is num) return valor;
    throw const DashboardException('Resposta inválida do servidor.');
  }

  static num? _numeroOpcional(Object? valor) {
    if (valor == null) return null;
    return _numero(valor);
  }
}
