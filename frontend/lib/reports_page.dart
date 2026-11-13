import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'reports_service.dart';

const _azulEscuro = Color(0xFF172554);
const _azulPrincipal = Color(0xFF1976B9);
const _cinzaTexto = Color(0xFF667D95);
const _fundoCard = Color(0xFFF8FAFD);
const _cores = [Color(0xFF1976B9), Color(0xFF00A878), Color(0xFF8B5CF6)];

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, this.service, this.revision = 0, this.accessToken});

  final RelatoriosService? service;
  final int revision;
  final String? accessToken;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final RelatoriosService _service;
  ResumoRelatorios? _resumo;
  bool _carregando = true;
  bool _gerandoAnalise = false;
  String? _erro;
  String? _analiseIa;
  String? _erroAnaliseIa;
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RelatoriosService(accessToken: widget.accessToken);
    _carregarResumo();
  }

  @override
  void didUpdateWidget(covariant ReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _carregarResumo();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _carregarResumo() async {
    final consulta = ++_consulta;
    setState(() { _carregando = true; _erro = null; });
    try {
      final resumo = await _service.resumo(
        granularidade: 'diaria',
      );
      if (!mounted || consulta != _consulta) return;
      setState(() { _resumo = resumo; _analiseIa = null; _erroAnaliseIa = null; });
    } on RelatoriosException catch (erro) {
      if (mounted && consulta == _consulta) setState(() => _erro = erro.mensagem);
    } finally {
      if (mounted && consulta == _consulta) setState(() => _carregando = false);
    }
  }

  List<Map<String, dynamic>> get _serie => _resumo?.serie ?? const [];

  List<Map<String, dynamic>> get _periodosOperacao => _serie
      .where((p) => (p['dias_operacao'] as num? ?? 0) > 0)
      .toList();

  List<(double, double)> _pares(String campoX, String campoY) {
    final resultado = <(double, double)>[];
    for (final p in _periodosOperacao) {
      final x = p[campoX];
      final y = p[campoY];
      if (x is num && y is num) resultado.add((x.toDouble(), y.toDouble()));
    }
    return resultado;
  }

  Map<String, dynamic> _relacao(String campoX, String campoY, String nomeX, String nomeY) {
    final pares = _pares(campoX, campoY);
    final n = pares.length;
    if (n < 2) return {'x': nomeX, 'y': nomeY, 'n': n};
    final mx = pares.fold<double>(0, (s, p) => s + p.$1) / n;
    final my = pares.fold<double>(0, (s, p) => s + p.$2) / n;
    var xx = 0.0, yy = 0.0, xy = 0.0;
    for (final p in pares) {
      xx += (p.$1 - mx) * (p.$1 - mx);
      yy += (p.$2 - my) * (p.$2 - my);
      xy += (p.$1 - mx) * (p.$2 - my);
    }
    final cov = xy / (n - 1);
    final r = xx == 0 || yy == 0 ? null : xy / math.sqrt(xx * yy);
    final b = xx == 0 ? null : xy / xx;
    final a = b == null ? null : my - b * mx;
    double? t, critical;
    if (r != null && n >= 3 && r.abs() < 1) {
      final df = n - 2;
      t = r * math.sqrt(df / (1 - r * r));
      const t95 = <int, double>{
        1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447,
        7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228, 11: 2.201, 12: 2.179,
        13: 2.160, 14: 2.145, 15: 2.131, 16: 2.120, 17: 2.110,
        18: 2.101, 19: 2.093, 20: 2.086, 21: 2.080, 22: 2.074,
        23: 2.069, 24: 2.064, 25: 2.060, 26: 2.056, 27: 2.052,
        28: 2.048, 29: 2.045, 30: 2.042,
      };
      critical = t95[df] ?? (df <= 40 ? 2.021 : df <= 60 ? 2.000 : df <= 120 ? 1.980 : 1.960);
    }
    return {
      'x': nomeX, 'y': nomeY, 'n': n,
      'covariancia_amostral': cov,
      'correlacao_pearson': r,
      'reta_regressao': b == null ? null : {'intercepto': a, 'inclinacao': b},
      'r_quadrado': r == null ? null : r * r,
      'teste_t': t == null ? null : {
        't': t, 'graus_de_liberdade': n - 2,
        'significativa_5_percento': t.abs() > critical!,
      },
    };
  }

  Map<String, dynamic> _resumoValores(String campo) {
    final valores = _periodosOperacao.map((p) => p[campo]).whereType<num>()
        .map((v) => v.toDouble()).toList()..sort();
    if (valores.isEmpty) return {'amostras': 0};
    final media = valores.reduce((a, b) => a + b) / valores.length;
    final variancia = valores.map((v) => (v - media) * (v - media))
        .reduce((a, b) => a + b) / valores.length;
    final mediana = valores.length.isOdd
        ? valores[valores.length ~/ 2]
        : (valores[valores.length ~/ 2 - 1] + valores[valores.length ~/ 2]) / 2;
    return {'amostras': valores.length, 'media': media, 'mediana': mediana,
      'desvio_padrao': math.sqrt(variancia), 'minimo': valores.first, 'maximo': valores.last};
  }

  Map<String, dynamic> _outliers(String campo, String nome) {
    final dados = _periodosOperacao
        .where((p) => p[campo] is num)
        .map((p) => (p['periodo'].toString(), (p[campo] as num).toDouble()))
        .toList()..sort((a, b) => a.$2.compareTo(b.$2));
    if (dados.length < 4) return {'indicador': nome, 'limite_inferior': null, 'limite_superior': null, 'pontos': <Object>[]};
    double mediana(List<double> v) => v.length.isOdd ? v[v.length ~/ 2]
        : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;
    final valores = dados.map((p) => p.$2).toList();
    final meio = valores.length ~/ 2;
    final q1 = mediana(valores.take(meio).toList());
    final q3 = mediana(valores.skip((valores.length + 1) ~/ 2).toList());
    final iqr = q3 - q1;
    final inferior = q1 - 1.5 * iqr;
    final superior = q3 + 1.5 * iqr;
    return {'indicador': nome, 'limite_inferior': inferior, 'limite_superior': superior,
      'pontos': dados.where((p) => p.$2 < inferior || p.$2 > superior)
          .map((p) => {'periodo': p.$1, 'valor': p.$2}).toList()};
  }

  Map<String, dynamic>? _prever(String campo, String nome, int horizonte) {
    final dados = _periodosOperacao.where((p) => p[campo] is num)
        .map((p) => (p['periodo'].toString(), (p[campo] as num).toDouble())).toList();
    if (dados.length < 5) return null;
    final n = dados.length;
    final mx = (n - 1) / 2;
    final my = dados.fold<double>(0, (s, p) => s + p.$2) / n;
    var xx = 0.0, xy = 0.0, sse = 0.0;
    for (var i = 0; i < n; i++) {
      xx += (i - mx) * (i - mx);
      xy += (i - mx) * (dados[i].$2 - my);
    }
    if (xx == 0) return null;
    final slope = xy / xx;
    final intercept = my - slope * mx;
    for (var i = 0; i < n; i++) {
      final erro = dados[i].$2 - (intercept + slope * i);
      sse += erro * erro;
    }
    final rmse = math.sqrt(sse / n);
    final previsoes = <Map<String, dynamic>>[];
    for (var passo = 1; passo <= horizonte; passo++) {
      final previsto = math.max(0.0, intercept + slope * (n - 1 + passo));
      previsoes.add({'periodo': _rotuloFuturo(dados.last.$1, passo), 'valor': previsto});
    }
    return {'indicador': nome, 'n': n, 'inclinacao_por_periodo': slope,
      'rmse_historico': rmse, 'previsoes': previsoes,
      'historico': dados.map((p) => {'periodo': p.$1, 'valor': p.$2}).toList()};
  }

  String _rotuloFuturo(String ultimo, int passo) {
    final data = DateTime.tryParse(ultimo);
    if (data == null) return 'Previsão $passo';
    return data.add(Duration(days: passo)).toIso8601String().substring(0, 10);
  }

  Map<String, dynamic> _estatisticas() {
    final serie = _serie;
    final op = _periodosOperacao;
    final paresProgramados = op.where((p) => p['viagens_programadas'] is num && p['viagens_realizadas'] is num).toList();
    final programadas = paresProgramados.fold<double>(0, (s, p) => s + (p['viagens_programadas'] as num).toDouble());
    final realizadas = paresProgramados.fold<double>(0, (s, p) => s + (p['viagens_realizadas'] as num).toDouble());
    double? somar(String campo) {
      final valores = op.map((p) => p[campo]).whereType<num>();
      if (valores.isEmpty) return null;
      return valores.fold<double>(0, (s, v) => s + v.toDouble());
    }
    final km = somar('quilometragem_km');
    final totalViagens = somar('viagens_realizadas');
    final passageiros = somar('total_passageiros');
    final pagantes = somar('passageiros_pagantes');
    final valoresRelacao = <Map<String, dynamic>>[
      _relacao('viagens_programadas', 'viagens_realizadas', 'Viagens programadas', 'Viagens realizadas'),
      _relacao('viagens_realizadas', 'quilometragem_km', 'Viagens realizadas', 'Quilometragem (km)'),
      _relacao('viagens_realizadas', 'total_passageiros', 'Viagens realizadas', 'Passageiros'),
      _relacao('total_passageiros', 'total_vendas', 'Passageiros', 'Vendas'),
    ].where((r) => (r['n'] as int) >= 2).toList();
    final variaveis = [
      ('viagens_realizadas', 'Viagens'), ('quilometragem_km', 'Km'), ('total_passageiros', 'Passageiros'),
    ];
    final matriz = <String, Map<String, double?>>{};
    for (final (campoX, nomeX) in variaveis) {
      if (op.where((p) => p[campoX] is num).length < 2) continue;
      final linha = <String, double?>{};
      for (final (campoY, nomeY) in variaveis) {
        if (op.where((p) => p[campoY] is num).length < 2) continue;
        final pares = _pares(campoX, campoY);
        if (pares.length < 2) { linha[nomeY] = null; continue; }
        final mx = pares.fold<double>(0, (s, p) => s + p.$1) / pares.length;
        final my = pares.fold<double>(0, (s, p) => s + p.$2) / pares.length;
        linha[nomeY] = pares.fold<double>(0, (s, p) => s + (p.$1 - mx) * (p.$2 - my)) / (pares.length - 1);
      }
      matriz[nomeX] = linha;
    }
    const horizon = 7;
    final previsoes = <Map<String, dynamic>?>[
      _prever('viagens_realizadas', 'Viagens realizadas', horizon),
      _prever('quilometragem_km', 'Quilometragem (km)', horizon),
      _prever('total_passageiros', 'Passageiros', horizon),
    ].whereType<Map<String, dynamic>>().toList();
    final ultimaVariacao = op.length >= 2 && op[op.length - 2]['viagens_realizadas'] is num && op.last['viagens_realizadas'] is num
        ? () {
            final ant = op[op.length - 2]['viagens_realizadas'] as num;
            final atual = op.last['viagens_realizadas'] as num;
            return ant == 0 ? null : (atual - ant) / ant * 100;
          }()
        : null;
    return {
      'periodo_analisado': serie.isEmpty ? null : '${serie.first['periodo']} a ${serie.last['periodo']}',
      'periodos_com_operacao': op.length,
      'viagens_realizadas': _resumoValores('viagens_realizadas'),
      'quilometragem_km': _resumoValores('quilometragem_km'),
      'taxa_realizacao_percentual': programadas > 0 ? realizadas / programadas * 100 : null,
      'km_por_viagem': totalViagens != null && totalViagens > 0 && km != null ? km / totalViagens : null,
      'passageiros_por_viagem': totalViagens != null && totalViagens > 0 && passageiros != null ? passageiros / totalViagens : null,
      'participacao_pagantes_percentual': passageiros != null && passageiros > 0 && pagantes != null ? pagantes / passageiros * 100 : null,
      'variacao_ultimo_periodo_percentual': ultimaVariacao,
      'relacoes': valoresRelacao,
      'matriz_covariancia_amostral': matriz,
      'outliers_viagens': _outliers('viagens_realizadas', 'Viagens realizadas'),
      'outliers_km': _outliers('quilometragem_km', 'Quilometragem (km)'),
      'previsoes_lineares': previsoes,
      'nota_previsao': 'Extrapolação de tendência linear; não incorpora calendário, clima, eventos ou mudanças operacionais.',
      'nota_regressao_logistica': 'Não calculada: não há desfecho binário validado nos dados disponíveis.',
      'totais': _resumo?.indicadores,
    };
  }

  Map<int, double> _mediasPorDiaSemana(String campo) {
    final soma = <int, double>{};
    final contagem = <int, int>{};
    for (final p in _serie) {
      if ((p['dias_operacao'] as num? ?? 0) <= 0) continue;
      if (p[campo] is! num) continue;
      final data = DateTime.tryParse(p['periodo'].toString());
      if (data == null) continue;
      soma.update(data.weekday, (v) => v + (p[campo] as num).toDouble(), ifAbsent: () => (p[campo] as num).toDouble());
      contagem.update(data.weekday, (v) => v + 1, ifAbsent: () => 1);
    }
    return {for (final dia in soma.keys) dia: soma[dia]! / contagem[dia]!};
  }

  Future<void> _gerarAnaliseIa() async {
    if (_serie.isEmpty) return;
    setState(() { _gerandoAnalise = true; _erroAnaliseIa = null; });
    try {
      final resultado = await _service.analisar(_estatisticas());
      if (mounted) setState(() => _analiseIa = resultado);
    } on RelatoriosException catch (erro) {
      if (mounted) setState(() => _erroAnaliseIa = erro.mensagem);
    } finally {
      if (mounted) setState(() => _gerandoAnalise = false);
    }
  }

  String _numero(num? valor, {int casas = 1}) => valor == null ? 'N/D' : valor.toStringAsFixed(casas);
  String _moeda(num? valor) => valor == null ? 'N/D' : 'R\$ ${valor.toStringAsFixed(2)}';

  Widget _cartaoIndicador(String titulo, String valor, IconData icone, {String? detalhe}) => SizedBox(
    width: 225,
    child: Card(color: _fundoCard, elevation: 0, shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFD4E0ED))),
      child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
        Icon(icone, color: _azulPrincipal), const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(color: _cinzaTexto, fontSize: 12)),
          const SizedBox(height: 4), Text(valor, style: const TextStyle(color: _azulEscuro, fontWeight: FontWeight.bold, fontSize: 18)),
          if (detalhe != null) Text(detalhe, style: const TextStyle(color: _cinzaTexto, fontSize: 11)),
        ])),
      ]))),
  );

  Widget _secao(String titulo, String descricao, List<Widget> filhos) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: const TextStyle(color: _azulEscuro, fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4), Text(descricao, style: const TextStyle(color: _cinzaTexto, fontSize: 13)),
      const SizedBox(height: 10), ...filhos,
    ]),
  );

  Widget _cartoesPrincipais(Map<String, dynamic> calc) {
    final indicadores = _resumo?.indicadores ?? const <String, dynamic>{};
    final taxa = calc['taxa_realizacao_percentual'] as num?;
    final totalPassageiros = indicadores['total_passageiros'] as num?;
    final pagantesPercentual = calc['participacao_pagantes_percentual'] as num?;
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _cartaoIndicador('Viagens realizadas', _numero(indicadores['viagens_realizadas'] as num?, casas: 0), Icons.directions_bus),
      _cartaoIndicador('Cumprimento da programação', taxa == null ? 'N/D' : '${_numero(taxa)}%', Icons.task_alt),
      _cartaoIndicador('Quilometragem', '${_numero(indicadores['quilometragem_km'] as num?)} km', Icons.route),
      _cartaoIndicador('Km por viagem', _numero(calc['km_por_viagem'] as num?), Icons.alt_route),
      _cartaoIndicador('Passageiros', _numero(totalPassageiros, casas: 0), Icons.people_alt_outlined),
      _cartaoIndicador('Passageiros por viagem', _numero(calc['passageiros_por_viagem'] as num?), Icons.groups_2_outlined),
      _cartaoIndicador('Pagantes no total', pagantesPercentual == null ? 'N/D' : '${_numero(pagantesPercentual)}%', Icons.payments_outlined),
      _cartaoIndicador('Vendas', _moeda(indicadores['total_vendas'] as num?), Icons.point_of_sale),
    ]);
  }

  Widget _outlierCard(Map<String, dynamic> dados) {
    final pontos = dados['pontos'] as List;
    return Card(color: const Color(0xFFFFF8E8), elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(dados['indicador'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, color: _azulEscuro)),
        const SizedBox(height: 4),
        Text(pontos.isEmpty ? 'Nenhum ponto além de 1,5 × IQR.' : pontos.map((p) => '${p['periodo']}: ${_numero(p['valor'] as num)}').join('  ·  '),
          style: const TextStyle(color: _cinzaTexto)),
      ],
    )));
  }

  Widget _graficoPrevisao(Map<String, dynamic> previsao) {
    final historico = (previsao['historico'] as List).cast<Map<String, dynamic>>();
    final futuro = (previsao['previsoes'] as List).cast<Map<String, dynamic>>();
    if (historico.length < 2 || futuro.isEmpty) return const SizedBox.shrink();
    final inicio = math.max(0, historico.length - 36).toInt();
    final exibido = historico.skip(inicio).toList();
    final atualSpots = [for (var i = 0; i < exibido.length; i++)
      FlSpot(i.toDouble(), (exibido[i]['valor'] as num).toDouble())];
    final previsaoSpots = <FlSpot>[
      FlSpot((exibido.length - 1).toDouble(), (exibido.last['valor'] as num).toDouble()),
      for (var i = 0; i < futuro.length; i++)
        FlSpot((exibido.length + i).toDouble(), (futuro[i]['valor'] as num).toDouble()),
    ];
    final labels = [...exibido.map((p) => p['periodo'].toString()), ...futuro.map((p) => p['periodo'].toString())];
    final cor = _cores[previsao['indicador'] == 'Viagens realizadas' ? 0 : previsao['indicador'] == 'Quilometragem (km)' ? 1 : 2];
    return Card(color: _fundoCard, elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(previsao['indicador'].toString(), style: const TextStyle(color: _azulEscuro, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(spacing: 12, children: [
          _legenda(cor, 'Histórico'),
          _legenda(cor.withOpacity(.65), 'Previsão linear'),
        ]),
        const SizedBox(height: 6),
        SizedBox(height: 220, child: LineChart(LineChartData(
          minX: 0, maxX: (labels.length - 1).toDouble(),
          lineBarsData: [
            LineChartBarData(spots: atualSpots, color: cor, barWidth: 3, dotData: const FlDotData(show: false)),
            LineChartBarData(spots: previsaoSpots, color: cor.withOpacity(.65), barWidth: 3, dashArray: [6, 4], dotData: const FlDotData(show: true)),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34,
              interval: math.max(1, (labels.length / 5).ceil()).toDouble(),
              getTitlesWidget: (x, meta) { final i = x.toInt(); if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                final label = labels[i]; return SideTitleWidget(meta: meta, child: Text(label.length > 7 ? label.substring(5) : label, style: const TextStyle(fontSize: 9, color: _cinzaTexto))); })),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45)),
          ),
          gridData: const FlGridData(drawVerticalLine: false), borderData: FlBorderData(show: false),
        ))),
        Text('Valores previstos: ${futuro.map((p) => '${p['periodo']}: ${_numero(p['valor'] as num)}').join(' · ')}',
          style: const TextStyle(color: _azulEscuro, fontSize: 12)),
        Text('Tendência: ${_numero(previsao['inclinacao_por_periodo'] as num)} por período; erro histórico (RMSE): ${_numero(previsao['rmse_historico'] as num)}.',
          style: const TextStyle(color: _cinzaTexto, fontSize: 12)),
      ],
    )));
  }

  Widget _legenda(Color cor, String rotulo) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 15, height: 3, color: cor),
    const SizedBox(width: 5),
    Text(rotulo, style: const TextStyle(color: _cinzaTexto, fontSize: 11)),
  ]);

  Widget _relacaoCard(Map<String, dynamic> r) {
    final corr = r['correlacao_pearson'] as num?;
    final cov = r['covariancia_amostral'] as num?;
    final reta = r['reta_regressao'] as Map<String, dynamic>?;
    final teste = r['teste_t'] as Map<String, dynamic>?;
    return Card(color: _fundoCard, elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r['y']} em função de ${r['x']}', style: const TextStyle(color: _azulEscuro, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text('n = ${r['n']} · Pearson r = ${_numero(corr, casas: 3)} · Covariância = ${_numero(cov, casas: 3)}', style: const TextStyle(color: _cinzaTexto, fontSize: 12)),
        if (reta != null) Text('ŷ = ${_numero(reta['intercepto'] as num?, casas: 3)} + ${_numero(reta['inclinacao'] as num?, casas: 3)}x · R² = ${_numero(r['r_quadrado'] as num?, casas: 3)}', style: const TextStyle(color: _azulEscuro)),
        if (teste != null) Text('Teste t bilateral: ${_numero(teste['t'] as num?, casas: 2)}, gl ${teste['graus_de_liberdade']} · ${teste['significativa_5_percento'] == true ? 'significativa' : 'não significativa'} a 5%', style: const TextStyle(color: _cinzaTexto, fontSize: 12)),
        if (corr == null) const Text('Correlação indefinida: uma das variáveis não apresenta variação.', style: TextStyle(color: _cinzaTexto, fontSize: 12)),
      ],
    )));
  }

  Widget _tabelaCovariancia(Map matriz) {
    final nomes = matriz.keys.cast<String>().toList();
    if (nomes.isEmpty) return const SizedBox.shrink();
    return Card(color: _fundoCard, elevation: 0, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      columns: [const DataColumn(label: Text('Variável')), ...nomes.map((n) => DataColumn(label: Text(n)))],
      rows: nomes.map((linha) {
        final dados = Map<String, dynamic>.from(matriz[linha] as Map);
        return DataRow(cells: [DataCell(Text(linha)), ...nomes.map((n) => DataCell(Text(_numero(dados[n] as num?, casas: 2))))]);
      }).toList(),
    )));
  }

  Widget _diaSemana() {
    const nomes = {1: 'Segunda', 2: 'Terça', 3: 'Quarta', 4: 'Quinta', 5: 'Sexta', 6: 'Sábado', 7: 'Domingo'};
    final mediasViagens = _mediasPorDiaSemana('viagens_realizadas');
    final mediasPassageiros = _mediasPorDiaSemana('total_passageiros');
    if (mediasViagens.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Não há dados diários para comparar.')));
    return Card(color: _fundoCard, elevation: 0, child: Column(children: [
      for (final dia in mediasViagens.keys.toList()..sort())
        ListTile(dense: true, title: Text(nomes[dia]!), subtitle: Text('Passageiros/dia: ${_numero(mediasPassageiros[dia])}'), trailing: Text('${_numero(mediasViagens[dia])} viagens/dia')),
    ]));
  }

  Widget _painelAnaliseIa() => Card(color: const Color(0xFFF0F7FC), elevation: 0, child: Padding(padding: const EdgeInsets.all(15), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Análise assistida por IA', style: TextStyle(color: _azulEscuro, fontSize: 16, fontWeight: FontWeight.bold))),
        FilledButton.icon(onPressed: _gerandoAnalise ? null : _gerarAnaliseIa,
          icon: _gerandoAnalise ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
          label: Text(_analiseIa == null ? 'Analisar' : 'Atualizar'))]),
      const SizedBox(height: 5), const Text('A IA comenta apenas os cálculos, relações e previsões apresentados nesta página.', style: TextStyle(color: _cinzaTexto, fontSize: 12)),
      if (_erroAnaliseIa != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_erroAnaliseIa!, style: const TextStyle(color: Color(0xFFB42318)))),
      if (_analiseIa != null) Padding(padding: const EdgeInsets.only(top: 10), child: SelectableText(_analiseIa!, style: const TextStyle(color: _azulEscuro, height: 1.5))),
    ],
  )));

  @override
  Widget build(BuildContext context) {
    final calc = _resumo == null ? null : _estatisticas();
    final relacoes = (calc?['relacoes'] as List<Map<String, dynamic>>?) ?? const [];
    final previsoes = (calc?['previsoes_lineares'] as List<Map<String, dynamic>>?) ?? const [];
    return SingleChildScrollView(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1216),
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 28, 16, 32), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Análises e previsões', style: TextStyle(color: _azulEscuro, fontSize: 25, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text('Indicadores estatísticos calculados a partir dos relatórios importados.', style: TextStyle(color: _cinzaTexto)),
          const SizedBox(height: 18),
          if (_carregando) const Padding(padding: EdgeInsets.only(top: 18), child: LinearProgressIndicator()),
          if (_erro != null) Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_erro!, style: const TextStyle(color: Color(0xFFB42318))), TextButton(onPressed: _carregarResumo, child: const Text('Tentar novamente')),
          ]))),
          if (!_carregando && _erro == null && _resumo != null && _resumo!.serie.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Não há dados no intervalo selecionado.'))),
          if (calc != null && _serie.isNotEmpty) ...[
            _secao('Operação e demanda', 'Indicadores agregados no intervalo selecionado. Campos ausentes nos relatórios podem aparecer como zero na consolidação.', [_cartoesPrincipais(calc)]),
            _secao('Comparação por dia da semana', 'Médias observadas na série diária; diferenças não implicam causalidade.', [_diaSemana()]),
            _secao('Relações entre indicadores', 'Covariância, correlação de Pearson, regressão linear e teste t bilateral.', [
              if (relacoes.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Não há períodos pareados suficientes para estimar relações.'))),
              ...relacoes.map(_relacaoCard),
              if ((calc['matriz_covariancia_amostral'] as Map).isNotEmpty) ...[
                const Padding(padding: EdgeInsets.only(top: 8, bottom: 4), child: Text('Matriz de covariância amostral (diagonal = variâncias).', style: TextStyle(color: _cinzaTexto))),
                _tabelaCovariancia(calc['matriz_covariancia_amostral'] as Map),
              ],
              const Padding(padding: EdgeInsets.only(top: 4), child: Text('Correlação mede associação, não causa. O teste t é indicativo porque observações de séries temporais podem ser dependentes.', style: TextStyle(color: _cinzaTexto, fontSize: 12))),
            ]),
            _secao('Pontos fora do padrão', 'Regra de 1,5 × intervalo interquartil; sinaliza valores para revisão.', [
              _outlierCard(calc['outliers_viagens'] as Map<String, dynamic>),
              _outlierCard(calc['outliers_km'] as Map<String, dynamic>),
            ]),
            _secao('Previsões por tendência linear', 'Extrapolação dos períodos anteriores. Requer pelo menos cinco observações e não representa uma garantia.', [
              if (previsoes.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Histórico insuficiente para previsão: são necessários pelo menos cinco períodos com dados.'))),
              ...previsoes.map(_graficoPrevisao),
              const Card(color: Color(0xFFFFF8E8), child: Padding(padding: EdgeInsets.all(13), child: Text('As previsões não consideram calendário, clima, eventos nem mudanças de oferta. O RMSE resume o erro dentro do histórico e não é um intervalo de confiança.'))),
            ]),
            _secao('Análise narrativa', 'Síntese da IA baseada nos resultados calculados acima.', [_painelAnaliseIa()]),
          ],
        ],
      )),
    )));
  }
}
