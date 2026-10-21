import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'dashboard_service.dart';

const _azulEscuro = Color(0xFF173F68);
const _azul = Color(0xFF1976B9);
const _azulClaro = Color(0xFF79A9CF);
const _textoSuave = Color(0xFF667D95);

class DashboardFiltro extends StatelessWidget {
  const DashboardFiltro({
    super.key,
    required this.titulo,
    required this.chave,
    required this.valor,
    required this.valores,
    required this.aoMudar,
  });

  final String titulo;
  final Key chave;
  final String? valor;
  final List<String> valores;
  final ValueChanged<String?> aoMudar;

  @override
  Widget build(BuildContext context) => _filtro(
        titulo: titulo,
        chave: chave,
        valor: valor,
        valores: valores,
        aoMudar: aoMudar,
      );
}

class DashboardMensagem extends StatelessWidget {
  const DashboardMensagem({super.key, required this.mensagem, this.onRetry});

  final String mensagem;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _mensagem(mensagem, onRetry: onRetry);
}

class DashboardIndicadoresCards extends StatelessWidget {
  const DashboardIndicadoresCards({super.key, required this.resumo});

  final DashboardResumo resumo;

  @override
  Widget build(BuildContext context) => _indicadores(resumo);
}

class DashboardEvolucao extends StatelessWidget {
  const DashboardEvolucao({super.key, required this.pontos});

  final List<EvolucaoPonto> pontos;

  @override
  Widget build(BuildContext context) => _evolucao(pontos);
}

class DashboardFaixas extends StatelessWidget {
  const DashboardFaixas({super.key, required this.faixas});

  final List<FaixaHorariaResumo> faixas;

  @override
  Widget build(BuildContext context) => _faixas(faixas);
}

class DashboardRanking extends StatelessWidget {
  const DashboardRanking({super.key, required this.linhas});

  final List<LinhaResumo> linhas;

  @override
  Widget build(BuildContext context) => _ranking(linhas);
}

Widget _filtro({
  required String titulo,
  required Key chave,
  required String? valor,
  required List<String> valores,
  required ValueChanged<String?> aoMudar,
}) {
  return SizedBox(
    width: 225,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
              color: _azulEscuro,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            )),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: chave,
              isExpanded: true,
              value: valor,
              items: valores
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ))
                  .toList(),
              onChanged: valores.length > 1 ? aoMudar : null,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _mensagem(String mensagem, {VoidCallback? onRetry}) {
  return _painel(
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: _azul),
        const SizedBox(width: 12),
        Expanded(
            child: Text(mensagem, style: const TextStyle(color: _azulEscuro))),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
      ],
    ),
  );
}

Widget _indicadores(DashboardResumo resumo) {
  final dados = resumo.indicadores;
  final itens = [
    (
      'Viagens programadas',
      dados.viagensProgramadas == null
          ? '—'
          : _inteiro(dados.viagensProgramadas!),
      Icons.event_note_outlined
    ),
    (
      'Viagens realizadas',
      dados.viagensRealizadas == null
          ? '—'
          : _inteiro(dados.viagensRealizadas!),
      Icons.directions_bus_outlined
    ),
    (
      'Quilometragem total',
      dados.quilometragemTotal == null
          ? '—'
          : '${_decimal(dados.quilometragemTotal!)} km',
      Icons.route_outlined
    ),
    (
      'Passageiros',
      dados.totalPassageiros == null ? '—' : _inteiro(dados.totalPassageiros!),
      Icons.groups_outlined
    ),
  ];
  return LayoutBuilder(builder: (context, constraints) {
    final largura = constraints.maxWidth;
    final colunas = largura >= 1000
        ? 4
        : largura >= 560
            ? 2
            : 1;
    final larguraCard = (largura - (colunas - 1) * 14) / colunas;
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: itens
          .map((item) => SizedBox(
                width: larguraCard,
                child: _painel(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.$3, color: _azul, size: 25),
                    const SizedBox(height: 13),
                    Text(item.$1,
                        style:
                            const TextStyle(color: _textoSuave, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(item.$2,
                        style: const TextStyle(
                          color: _azulEscuro,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                )),
              ))
          .toList(),
    );
  });
}

Widget _evolucao(List<EvolucaoPonto> pontos) {
  return _painel(
      child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _tituloPainel('Evolução diária', 'Viagens programadas e realizadas'),
      const SizedBox(height: 12),
      if (pontos.isEmpty)
        const SizedBox(
            height: 250,
            child: Center(child: Text('Sem dados diários neste período.')))
      else ...[
        _legenda([
          ('Programadas', _azulClaro),
          ('Realizadas', _azulEscuro),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 250,
          child: LineChart(_dadosLinha(pontos)),
        ),
      ],
    ],
  ));
}

LineChartData _dadosLinha(List<EvolucaoPonto> pontos) {
  final maior = pontos.fold<int>(
      1,
      (atual, ponto) => math.max(
            atual,
            math.max(ponto.viagensProgramadas, ponto.viagensRealizadas),
          ));
  final passo = math.max(1, (pontos.length / 6).ceil());
  final maxY = maior * 1.12;
  return LineChartData(
    minX: 0,
    maxX: math.max(1, pontos.length - 1).toDouble(),
    minY: 0,
    maxY: maxY,
    gridData: const FlGridData(drawVerticalLine: false),
    borderData: FlBorderData(show: false),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
          sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 44,
        interval: math.max(1, maxY / 4),
        getTitlesWidget: (valor, _) => Text(
          _rotuloEixo(valor),
          style: const TextStyle(fontSize: 10, color: _textoSuave),
        ),
      )),
      bottomTitles: AxisTitles(
          sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: 1,
        getTitlesWidget: (valor, _) {
          final indice = valor.toInt();
          if (indice < 0 || indice >= pontos.length || indice % passo != 0) {
            return const SizedBox.shrink();
          }
          final data = pontos[indice].data;
          return Text(
            data.length >= 10 ? data.substring(8, 10) : data,
            style: const TextStyle(fontSize: 10, color: _textoSuave),
          );
        },
      )),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: [
          for (var i = 0; i < pontos.length; i++)
            FlSpot(i.toDouble(), pontos[i].viagensProgramadas.toDouble())
        ],
        color: _azulClaro,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: [
          for (var i = 0; i < pontos.length; i++)
            FlSpot(i.toDouble(), pontos[i].viagensRealizadas.toDouble())
        ],
        color: _azulEscuro,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
      ),
    ],
  );
}

Widget _faixas(List<FaixaHorariaResumo> faixas) {
  return _painel(
      child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _tituloPainel('Faixas horárias', 'Número de viagens por faixa'),
      const SizedBox(height: 12),
      if (faixas.isEmpty)
        const SizedBox(
            height: 250,
            child: Center(
                child: Text('Sem dados de faixas horárias neste período.')))
      else ...[
        const SizedBox(height: 24),
        SizedBox(height: 250, child: BarChart(_dadosBarras(faixas))),
      ],
    ],
  ));
}

BarChartData _dadosBarras(List<FaixaHorariaResumo> faixas) {
  final maior =
      faixas.fold<int>(1, (atual, item) => math.max(atual, item.numeroViagens));
  final passo = math.max(1, (faixas.length / 6).ceil());
  final maxY = maior * 1.12;
  return BarChartData(
    maxY: maxY,
    alignment: BarChartAlignment.spaceAround,
    gridData: const FlGridData(drawVerticalLine: false),
    borderData: FlBorderData(show: false),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
          sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 44,
        interval: math.max(1, maxY / 4),
        getTitlesWidget: (valor, _) => Text(
          _rotuloEixo(valor),
          style: const TextStyle(fontSize: 10, color: _textoSuave),
        ),
      )),
      bottomTitles: AxisTitles(
          sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        getTitlesWidget: (valor, _) {
          final indice = valor.toInt();
          if (indice < 0 || indice >= faixas.length || indice % passo != 0) {
            return const SizedBox.shrink();
          }
          final rotulo = faixas[indice].faixaHoraria;
          return Text(rotulo.length > 5 ? rotulo.substring(0, 5) : rotulo,
              style: const TextStyle(fontSize: 10, color: _textoSuave));
        },
      )),
    ),
    barGroups: [
      for (var i = 0; i < faixas.length; i++)
        BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: faixas[i].numeroViagens.toDouble(),
            color: _azul,
            width: faixas.length > 16 ? 10 : 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          )
        ])
    ],
  );
}

Widget _ranking(List<LinhaResumo> linhas) {
  return _painel(
      child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _tituloPainel(
          'Linhas com mais viagens', 'Comparação das linhas no período'),
      const SizedBox(height: 18),
      if (linhas.isEmpty)
        const Text('Sem dados de linhas neste período.',
            style: TextStyle(color: _textoSuave))
      else
        for (final linha in linhas) ...[
          Row(children: [
            SizedBox(
                width: 90,
                child: Text('Linha ${linha.linha}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _azulEscuro, fontWeight: FontWeight.w600))),
            const SizedBox(width: 10),
            Expanded(
                child: LinearProgressIndicator(
              value: linhas.first.numeroViagens == 0
                  ? 0
                  : linha.numeroViagens / linhas.first.numeroViagens,
              minHeight: 9,
              color: _azul,
              backgroundColor: const Color(0xFFE6EFF7),
              borderRadius: BorderRadius.circular(6),
            )),
            const SizedBox(width: 10),
            SizedBox(
                width: 65,
                child: Text(_inteiro(linha.numeroViagens),
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: _azulEscuro))),
          ]),
          const SizedBox(height: 13),
        ],
    ],
  ));
}

Widget _tituloPainel(String titulo, String subtitulo) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
              color: _azulEscuro,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            )),
        const SizedBox(height: 4),
        Text(subtitulo,
            style: const TextStyle(color: _textoSuave, fontSize: 12)),
      ],
    );

Widget _legenda(List<(String, Color)> itens) => Wrap(
      spacing: 16,
      children: itens
          .map((item) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 3, color: item.$2),
                  const SizedBox(width: 5),
                  Text(item.$1,
                      style: const TextStyle(color: _textoSuave, fontSize: 11)),
                ],
              ))
          .toList(),
    );

Widget _painel({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9E3EC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );

String _inteiro(int valor) => valor.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

String _decimal(double valor) {
  final partes = valor.toStringAsFixed(1).split('.');
  return '${_inteiro(int.parse(partes[0]))},${partes[1]}';
}

String _rotuloEixo(double valor) {
  if (valor >= 1000000) return '${(valor / 1000000).toStringAsFixed(1)} mi';
  if (valor >= 1000) return '${(valor / 1000).toStringAsFixed(0)} mil';
  return valor.toInt().toString();
}
