import 'package:flutter/material.dart';

import 'dashboard_service.dart';
import 'dashboard_visuals.dart';

const _textoSuave = Color(0xFF667D95);

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    this.service,
    this.accessToken,
    this.revision = 0,
  });

  final DashboardService? service;
  final String? accessToken;
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
  DateTimeRange? _intervalo;
  final Set<String> _linhasSelecionadas = {};
  final Set<int> _diasSelecionados = {};
  int? _horaInicio;
  int? _horaFim;
  String? _erro;
  bool _carregandoOpcoes = true;
  bool _carregandoResumo = false;
  int _numeroConsulta = 0;
  int _numeroConsultaOpcoes = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DashboardService(accessToken: widget.accessToken);
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
      // A tela começa sem filtros para mostrar a agregação do banco inteiro.
      final periodo = opcoes.periodos.any((item) => item.periodo == _periodo)
          ? _periodo
          : null;
      final abrangencias = _abrangenciasDe(opcoes, periodo);
      final abrangencia = abrangencias.contains(_abrangencia) ? _abrangencia : null;
      setState(() {
        _opcoes = opcoes;
        _periodo = periodo;
        _abrangencia = abrangencia;
        _carregandoOpcoes = false;
      });
      await _carregarResumo();
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
    if (periodo == null) {
      return opcoes.periodos
          .expand((item) => item.abrangencias)
          .toSet()
          .toList()
        ..sort();
    }
    for (final item in opcoes.periodos) {
      if (item.periodo == periodo) return item.abrangencias;
    }
    return const [];
  }

  Future<void> _carregarResumo() async {
    final periodo = _periodo;
    final abrangencia = _abrangencia;
    final consulta = ++_numeroConsulta;
    setState(() {
      _carregandoResumo = true;
      _erro = null;
    });
    try {
      // Parâmetros nulos não são enviados; assim, a API calcula o total global.
      final resumo = await _service.buscarResumo(
        periodo: _intervalo == null ? periodo : null,
        abrangencia: abrangencia,
        inicio: _intervalo?.start,
        fim: _intervalo?.end,
        linhas: _linhasSelecionadas.toList()..sort(),
        diasSemana: _diasSelecionados.toList()..sort(),
        horaInicio: _horaInicio,
        horaFim: _horaFim,
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

  Widget _cartaoDialogoFiltro({
    required BuildContext contexto,
    required IconData icone,
    required String titulo,
    required Widget conteudo,
    required VoidCallback aoLimpar,
    required VoidCallback aoAplicar,
    bool aplicarHabilitado = true,
  }) {
    final tamanhoTela = MediaQuery.sizeOf(contexto);
    final larguraDialogo = (tamanhoTela.width - 40).clamp(0.0, 520.0).toDouble();
    final alturaMaxima = (tamanhoTela.height - 48)
        .clamp(0.0, tamanhoTela.height * 0.82)
        .toDouble();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: larguraDialogo, maxWidth: 520, maxHeight: alturaMaxima),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x260F2742), blurRadius: 30, offset: Offset(0, 14))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: const Color(0xFFEAF4FF), borderRadius: BorderRadius.circular(13)),
                  child: Icon(icone, color: const Color(0xFF1769AA)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(titulo, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF172554)))),
                IconButton(tooltip: 'Fechar', onPressed: () => Navigator.pop(contexto), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            const Divider(height: 1),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: conteudo)),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Row(children: [
                TextButton(onPressed: aoLimpar, child: const Text('Limpar filtro')),
                const Spacer(),
                FilledButton.icon(onPressed: aplicarHabilitado ? aoAplicar : null, icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Aplicar filtros')),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _abrirFiltroPeriodo() async {
    DateTime? inicio = _intervalo?.start;
    DateTime? fim = _intervalo?.end;
    var selecionandoInicio = inicio == null;
    final hoje = DateUtils.dateOnly(DateTime.now());
    final resultado = await showDialog<(DateTime?, DateTime?)>(
      context: context,
      builder: (dialogo) => StatefulBuilder(builder: (contexto, atualizar) => _cartaoDialogoFiltro(
        contexto: contexto,
        icone: Icons.calendar_month_outlined,
        titulo: 'Período de tempo',
        aoLimpar: () => atualizar(() { inicio = null; fim = null; selecionandoInicio = true; }),
        aoAplicar: () => Navigator.pop(dialogo, (inicio, fim)),
        aplicarHabilitado: (inicio == null && fim == null) || (inicio != null && fim != null),
        conteudo: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Selecione uma data inicial e uma data final no calendário.'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _campoDataIntervalo(
              titulo: 'Data inicial', data: inicio, selecionado: selecionandoInicio,
              aoTocar: () => atualizar(() => selecionandoInicio = true),
            )),
            const SizedBox(width: 10),
            Expanded(child: _campoDataIntervalo(
              titulo: 'Data final', data: fim, selecionado: !selecionandoInicio,
              aoTocar: () => atualizar(() => selecionandoInicio = false),
            )),
          ]),
          const SizedBox(height: 12),
          Center(child: CalendarDatePicker(
            initialDate: selecionandoInicio ? inicio ?? hoje : fim ?? inicio ?? hoje,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            currentDate: hoje,
            onDateChanged: (data) => atualizar(() {
              final dia = DateUtils.dateOnly(data);
              if (selecionandoInicio) {
                inicio = dia;
                if (fim != null && fim!.isBefore(dia)) fim = dia;
                selecionandoInicio = false;
              } else {
                fim = dia;
                if (inicio != null && dia.isBefore(inicio!)) inicio = dia;
              }
            }),
          )),
        ]),
      )),
    );
    if (resultado == null) return;
    setState(() {
      _periodo = null;
      _abrangencia = null;
      _intervalo = resultado.$1 == null || resultado.$2 == null
          ? null
          : DateTimeRange(start: resultado.$1!, end: resultado.$2!);
    });
    _carregarResumo();
  }

  // Apresenta cada extremo do intervalo como um campo selecionável.
  Widget _campoDataIntervalo({
    required String titulo,
    required DateTime? data,
    required bool selecionado,
    required VoidCallback aoTocar,
  }) {
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFFEAF4FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selecionado ? const Color(0xFF65A9E0) : const Color(0xFFDCE5EF)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontSize: 12, color: _textoSuave)),
          const SizedBox(height: 4),
          Text(data == null ? 'Selecionar' : _dataCurta(data), style: TextStyle(fontWeight: FontWeight.w700, color: selecionado ? const Color(0xFF1769AA) : const Color(0xFF173F68))),
        ]),
      ),
    );
  }

  // A lista longa permanece rolável sem expandir o diálogo além do limite.
  Future<void> _abrirFiltroLinhas(DashboardOpcoes opcoes) async {
    final selecionadas = Set<String>.from(_linhasSelecionadas);
    final resultado = await showDialog<Set<String>>(
      context: context,
      builder: (dialogo) => StatefulBuilder(builder: (contexto, atualizar) => _cartaoDialogoFiltro(
        contexto: contexto,
        icone: Icons.directions_bus_outlined,
        titulo: 'Linhas de ônibus',
        aoLimpar: () => atualizar(selecionadas.clear),
        aoAplicar: () => Navigator.pop(dialogo, Set<String>.from(selecionadas)),
        conteudo: Column(children: [for (final linha in opcoes.linhas) CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: selecionadas.contains(linha),
          title: Text('Linha $linha'),
          dense: true,
          activeColor: const Color(0xFF1769AA),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (marcada) => atualizar(() { if (marcada == true) { selecionadas.add(linha); } else { selecionadas.remove(linha); } }),
        )]),
      )),
    );
    if (resultado == null) return;
    setState(() { _linhasSelecionadas..clear()..addAll(resultado); });
    _carregarResumo();
  }

  // Os chips mostram visualmente os dias ativos antes de aplicar.
  Future<void> _abrirFiltroDias() async {
    final selecionados = Set<int>.from(_diasSelecionados);
    const dias = [(1, 'Segunda'), (2, 'Terça'), (3, 'Quarta'), (4, 'Quinta'), (5, 'Sexta'), (6, 'Sábado'), (7, 'Domingo')];
    final resultado = await showDialog<Set<int>>(
      context: context,
      builder: (dialogo) => StatefulBuilder(builder: (contexto, atualizar) => _cartaoDialogoFiltro(
        contexto: contexto,
        icone: Icons.today_outlined,
        titulo: 'Dias da semana',
        aoLimpar: () => atualizar(selecionados.clear),
        aoAplicar: () => Navigator.pop(dialogo, Set<int>.from(selecionados)),
        conteudo: Wrap(spacing: 8, runSpacing: 8, children: [for (final dia in dias) FilterChip(
          label: Text(dia.$2),
          selected: selecionados.contains(dia.$1),
          selectedColor: const Color(0xFFDCEEFF),
          checkmarkColor: const Color(0xFF1769AA),
          onSelected: (valor) => atualizar(() { if (valor) { selecionados.add(dia.$1); } else { selecionados.remove(dia.$1); } }),
        )]),
      )),
    );
    if (resultado == null) return;
    setState(() { _diasSelecionados..clear()..addAll(resultado); });
    _carregarResumo();
  }

  // Os dois seletores mantêm uma faixa válida antes da aplicação.
  Future<void> _abrirFiltroHorario() async {
    var inicio = _horaInicio;
    var fim = _horaFim;
    final resultado = await showDialog<(int?, int?)>(
      context: context,
      builder: (dialogo) => StatefulBuilder(builder: (contexto, atualizar) => _cartaoDialogoFiltro(
        contexto: contexto,
        icone: Icons.schedule_outlined,
        titulo: 'Faixa horária',
        aoLimpar: () => atualizar(() { inicio = null; fim = null; }),
        aoAplicar: () => Navigator.pop(dialogo, (inicio, fim)),
        conteudo: Row(children: [
          Expanded(child: _seletorHora(valor: inicio, titulo: 'A partir de', aoMudar: (valor) => atualizar(() { inicio = valor; if (valor != null && (fim == null || fim! < valor)) fim = valor; }))),
          const SizedBox(width: 12),
          Expanded(child: _seletorHora(valor: fim, titulo: 'Até', aoMudar: (valor) => atualizar(() { fim = valor; if (valor != null && (inicio == null || inicio! > valor)) inicio = valor; }))),
        ]),
      )),
    );
    if (resultado == null) return;
    setState(() { _horaInicio = resultado.$1; _horaFim = resultado.$2; });
    _carregarResumo();
  }

  Widget _botaoFiltro({required IconData icone, required String titulo, required String resumo, required bool ativo, required VoidCallback aoTocar}) {
    final destaque = ativo ? const Color(0xFF1769AA) : const Color(0xFF173F68);
    return SizedBox(width: 245, child: InkWell(
      key: Key('dashboard-filtro-$titulo'), onTap: aoTocar, borderRadius: BorderRadius.circular(14),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: ativo ? const Color(0xFFEAF4FF) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ativo ? const Color(0xFF8BC4F2) : const Color(0xFFDCE5EF))),
        child: Row(children: [Icon(icone, color: destaque), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, color: destaque)), const SizedBox(height: 3), Text(resumo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _textoSuave))])), if (ativo) Container(width: 8, height: 8, decoration: BoxDecoration(color: destaque, shape: BoxShape.circle))]),
      ),
    ));
  }

  String _dataCurta(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

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
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _botaoFiltro(icone: Icons.calendar_month_outlined, titulo: 'Período', resumo: _intervalo != null ? '${_dataCurta(_intervalo!.start)} – ${_dataCurta(_intervalo!.end)}' : 'Todos os períodos', ativo: _intervalo != null, aoTocar: _abrirFiltroPeriodo),
                  _botaoFiltro(icone: Icons.directions_bus_outlined, titulo: 'Linhas', resumo: _linhasSelecionadas.isEmpty ? 'Todas as linhas' : '${_linhasSelecionadas.length} selecionada(s)', ativo: _linhasSelecionadas.isNotEmpty, aoTocar: () => _abrirFiltroLinhas(opcoes)),
                  _botaoFiltro(icone: Icons.today_outlined, titulo: 'Dias da semana', resumo: _diasSelecionados.isEmpty ? 'Todos os dias' : '${_diasSelecionados.length} selecionado(s)', ativo: _diasSelecionados.isNotEmpty, aoTocar: _abrirFiltroDias),
                  _botaoFiltro(icone: Icons.schedule_outlined, titulo: 'Faixa horária', resumo: _horaInicio == null ? 'Todo o horário' : '${_horaInicio!.toString().padLeft(2, '0')}:00 – ${_horaFim!.toString().padLeft(2, '0')}:00', ativo: _horaInicio != null, aoTocar: _abrirFiltroHorario),
                ]),
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
                  '${resumo.abrangencia ?? "Todas as abrangências"} · ${resumo.periodo}',
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

  Widget _seletorHora({
    required int? valor,
    required String titulo,
    required ValueChanged<int?> aoMudar,
  }) {
    return SizedBox(
      width: 122,
      child: DropdownButtonFormField<int?>(
        value: valor,
        decoration: InputDecoration(
          labelText: titulo,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Qualquer')),
          for (var hora = 0; hora < 24; hora++)
            DropdownMenuItem<int?>(
              value: hora,
              child: Text('${hora.toString().padLeft(2, '0')}:00'),
            ),
        ],
        onChanged: aoMudar,
      ),
    );
  }
}
