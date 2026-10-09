import 'package:flutter/material.dart';

import 'dashboard_service.dart';
import 'dashboard_visuals.dart';

const _textoSuave = Color(0xFF667D95);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.service, this.revision = 0});

  final DashboardService? service;
  final int revision;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardService _service;
  DashboardOpcoes? _opcoes;
  DashboardResumo? _resumo;
  String? _periodo;
  String? _abrangencia;
  String? _erro;
  bool _carregandoOpcoes = true;
  bool _carregandoResumo = false;
  int _numeroConsulta = 0;
  int _numeroConsultaOpcoes = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DashboardService();
    _carregarOpcoes();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _carregarOpcoes();
  }

  Future<void> _carregarOpcoes() async {
    final consulta = ++_numeroConsultaOpcoes;
    ++_numeroConsulta;
    setState(() {
      _carregandoOpcoes = true;
      _carregandoResumo = false;
      _resumo = null;
      _erro = null;
    });
    try {
      final opcoes = await _service.buscarOpcoes();
      if (!mounted || consulta != _numeroConsultaOpcoes) return;
      final periodo = opcoes.periodos.any((item) => item.periodo == _periodo)
          ? _periodo
          : opcoes.periodos.any((item) => item.periodo == opcoes.periodoPadrao)
              ? opcoes.periodoPadrao
              : (opcoes.periodos.isEmpty
                  ? null
                  : opcoes.periodos.first.periodo);
      final abrangencias = _abrangenciasDe(opcoes, periodo);
      final abrangencia = abrangencias.contains(_abrangencia)
          ? _abrangencia
          : abrangencias.contains(opcoes.abrangenciaPadrao)
              ? opcoes.abrangenciaPadrao
              : (abrangencias.isEmpty ? null : abrangencias.first);
      setState(() {
        _opcoes = opcoes;
        _periodo = periodo;
        _abrangencia = abrangencia;
        _carregandoOpcoes = false;
      });
      if (periodo != null && abrangencia != null) {
        await _carregarResumo();
      }
    } on DashboardException catch (erro) {
      if (mounted && consulta == _numeroConsultaOpcoes) {
        setState(() {
          _opcoes = null;
          _erro = erro.mensagem;
          _carregandoOpcoes = false;
        });
      }
    }
  }

  List<String> _abrangenciasDe(DashboardOpcoes opcoes, String? periodo) {
    for (final item in opcoes.periodos) {
      if (item.periodo == periodo) return item.abrangencias;
    }
    return const [];
  }

  Future<void> _carregarResumo() async {
    final periodo = _periodo;
    final abrangencia = _abrangencia;
    if (periodo == null || abrangencia == null) return;
    final consulta = ++_numeroConsulta;
    setState(() {
      _carregandoResumo = true;
      _erro = null;
    });
    try {
      final resumo = await _service.buscarResumo(
        periodo: periodo,
        abrangencia: abrangencia,
      );
      if (mounted && consulta == _numeroConsulta) {
        setState(() {
          _resumo = resumo;
          _carregandoResumo = false;
        });
      }
    } on DashboardException catch (erro) {
      if (mounted && consulta == _numeroConsulta) {
        setState(() {
          _erro = erro.mensagem;
          _resumo = null;
          _carregandoResumo = false;
        });
      }
    }
  }

  void _selecionarPeriodo(String? periodo) {
    if (periodo == null || periodo == _periodo) return;
    final abrangencias = _abrangenciasDe(_opcoes!, periodo);
    setState(() {
      _periodo = periodo;
      if (!abrangencias.contains(_abrangencia)) {
        _abrangencia = abrangencias.isEmpty ? null : abrangencias.first;
      }
    });
    _carregarResumo();
  }

  void _selecionarAbrangencia(String? abrangencia) {
    if (abrangencia == null || abrangencia == _abrangencia) return;
    setState(() => _abrangencia = abrangencia);
    _carregarResumo();
  }

  @override
  Widget build(BuildContext context) {
    final opcoes = _opcoes;
    final resumo = _resumo;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1216),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172554),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Indicadores dos relatórios de transporte importados.',
                style: TextStyle(fontSize: 14, color: _textoSuave),
              ),
              const SizedBox(height: 24),
              if (opcoes != null && opcoes.periodos.isNotEmpty) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    DashboardFiltro(
                      titulo: 'Período',
                      chave: const Key('dashboard-periodo'),
                      valor: _periodo,
                      valores:
                          opcoes.periodos.map((item) => item.periodo).toList(),
                      aoMudar: _selecionarPeriodo,
                    ),
                    DashboardFiltro(
                      titulo: 'Tipo de relatório',
                      chave: const Key('dashboard-abrangencia'),
                      valor: _abrangencia,
                      valores: _abrangenciasDe(opcoes, _periodo),
                      aoMudar: _selecionarAbrangencia,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],
              if (_carregandoOpcoes || _carregandoResumo)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                )),
              if (_erro != null)
                DashboardMensagem(
                    mensagem: _erro!,
                    onRetry: _carregandoOpcoes || opcoes == null
                        ? _carregarOpcoes
                        : _carregarResumo),
              if (!_carregandoOpcoes &&
                  _erro == null &&
                  (opcoes == null || opcoes.periodos.isEmpty))
                const DashboardMensagem(
                    mensagem:
                        'Nenhum dado importado disponível para o Dashboard.'),
              if (!_carregandoResumo && _erro == null && resumo != null) ...[
                DashboardIndicadoresCards(resumo: resumo),
                const SizedBox(height: 12),
                Text(
                  '${resumo.indicadores.diasComDados} dias com dados · '
                  '${resumo.abrangencia} ${resumo.periodo}',
                  style: const TextStyle(color: _textoSuave, fontSize: 12),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(builder: (context, constraints) {
                  final largura = constraints.maxWidth;
                  final larguraGrafico =
                      largura >= 850 ? (largura - 16) / 2 : largura;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                          width: larguraGrafico,
                          child: DashboardEvolucao(pontos: resumo.evolucao)),
                      SizedBox(
                          width: larguraGrafico,
                          child:
                              DashboardFaixas(faixas: resumo.faixasHorarias)),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                DashboardRanking(linhas: resumo.linhas),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
