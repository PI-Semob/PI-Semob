import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'reports_service.dart';

const _azulEscuro = Color(0xFF172554);
const _azulPrincipal = Color(0xFF1976B9);
const _cinzaTexto = Color(0xFF667D95);
const _fundoCard = Color(0xFFF8FAFD);

class ReportsPage extends StatefulWidget {
  const ReportsPage(
      {super.key, this.service, this.revision = 0, this.accessToken});

  final RelatoriosService? service;
  final int revision;
  final String? accessToken;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final RelatoriosService _service;
  final TextEditingController _linha = TextEditingController();
  FiltrosRelatorios? _filtros;
  PaginaRelatorios? _pagina;
  String _periodo = '';
  String _tipo = '';
  String _abrangencia = '';
  String _linhaAplicada = '';
  String? _erroFiltros;
  String? _erroPagina;
  String? _erroResumo;
  bool _carregandoFiltros = true;
  bool _carregandoPagina = true;
  bool _carregandoResumo = true;
  bool _exportando = false;
  ResumoRelatorios? _resumo;
  String _granularidade = 'diaria';
  DateTimeRange? _intervalo;
  int _ultimaConsulta = 0;
  int _ultimaConsultaFiltros = 0;
  int _ultimaConsultaResumo = 0;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ?? RelatoriosService(accessToken: widget.accessToken);
    _carregarFiltros();
    _carregarPagina(1);
    _carregarResumo();
  }

  @override
  void didUpdateWidget(covariant ReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _recarregarAposImportacao();
    }
  }

  Future<void> _recarregarAposImportacao() async {
    final revisao = widget.revision;
    ++_ultimaConsulta;
    setState(() {
      _pagina = null;
      _erroPagina = null;
      _carregandoPagina = true;
    });
    await _carregarFiltros();
    if (!mounted || revisao != widget.revision) return;
    final filtros = _filtros;
    if (filtros != null) {
      setState(() {
        if (!filtros.periodos.contains(_periodo)) _periodo = '';
        if (!filtros.tipos.contains(_tipo)) _tipo = '';
        if (!filtros.abrangencias.contains(_abrangencia)) _abrangencia = '';
      });
    }
    await _carregarPagina(1);
    await _carregarResumo();
  }

  @override
  void dispose() {
    _linha.dispose();
    super.dispose();
  }

  Future<void> _carregarFiltros() async {
    final consulta = ++_ultimaConsultaFiltros;
    setState(() {
      _carregandoFiltros = true;
      _erroFiltros = null;
    });
    try {
      final filtros = await _service.filtros();
      if (!mounted || consulta != _ultimaConsultaFiltros) return;
      setState(() => _filtros = filtros);
    } on RelatoriosException catch (erro) {
      if (!mounted || consulta != _ultimaConsultaFiltros) return;
      setState(() => _erroFiltros = erro.mensagem);
    } finally {
      if (mounted && consulta == _ultimaConsultaFiltros) {
        setState(() => _carregandoFiltros = false);
      }
    }
  }

  Future<void> _carregarPagina(int numero) async {
    final consulta = ++_ultimaConsulta;
    setState(() {
      _carregandoPagina = true;
      _erroPagina = null;
    });
    try {
      final pagina = await _service.listar(
        pagina: numero,
        tipo: _tipo,
        periodo: _periodo,
        abrangencia: _abrangencia,
        linha: _linhaAplicada,
      );
      if (!mounted || consulta != _ultimaConsulta) return;
      setState(() => _pagina = pagina);
    } on RelatoriosException catch (erro) {
      if (!mounted || consulta != _ultimaConsulta) return;
      setState(() => _erroPagina = erro.mensagem);
    } finally {
      if (mounted && consulta == _ultimaConsulta) {
        setState(() => _carregandoPagina = false);
      }
    }
  }

  void _aplicarFiltros() {
    _linhaAplicada = _linha.text.trim();
    _carregarPagina(1);
    _carregarResumo();
  }

  Future<void> _carregarResumo() async {
    final consulta = ++_ultimaConsultaResumo;
    if (mounted) {
      setState(() {
        _carregandoResumo = true;
        _erroResumo = null;
      });
    }
    try {
      final resumo = await _service.resumo(
        granularidade: _granularidade,
        inicio: _intervalo?.start,
        fim: _intervalo?.end,
        linha: _linhaAplicada,
      );
      if (mounted && consulta == _ultimaConsultaResumo) {
        setState(() => _resumo = resumo);
      }
    } on RelatoriosException catch (erro) {
      if (mounted && consulta == _ultimaConsultaResumo) {
        setState(() => _erroResumo = erro.mensagem);
      }
    } finally {
      if (mounted && consulta == _ultimaConsultaResumo) {
        setState(() => _carregandoResumo = false);
      }
    }
  }

  Future<void> _selecionarIntervalo() async {
    final agora = DateTime.now();
    final intervalo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: agora.add(const Duration(days: 365)),
      initialDateRange: _intervalo ??
          DateTimeRange(
            start: DateTime(agora.year, agora.month, 1),
            end: agora,
          ),
      helpText: 'Selecione o intervalo dos indicadores',
    );
    if (intervalo == null || !mounted) return;
    setState(() => _intervalo = intervalo);
    _carregarResumo();
  }

  Future<void> _exportarCsv() async {
    setState(() => _exportando = true);
    try {
      final bytes = await _service.exportarCsv(
        tipo: _tipo,
        periodo: _periodo,
        linha: _linhaAplicada,
        abrangencia: _abrangencia,
      );
      final arquivo = await FilePicker.platform.saveFile(
        fileName: 'relatorios_semob.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(bytes),
      );
      if (arquivo != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV exportado com sucesso.')),
        );
      }
    } on RelatoriosException catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erro.mensagem)),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  String _rotuloPeriodo(String periodo) {
    final partes = periodo.split('-');
    if (partes.length == 2 && partes[0].length == 4 && partes[1].length == 2) {
      return '${partes[1]}/${partes[0]}';
    }
    return periodo;
  }

  Widget _seletor({
    required String chave,
    required String titulo,
    required String valor,
    required String todos,
    required List<String> opcoes,
    required ValueChanged<String> aoAlterar,
    String Function(String)? rotulo,
  }) {
    return SizedBox(
      width: 205,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: titulo,
          labelStyle: const TextStyle(color: _cinzaTexto),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: Key(chave),
            isExpanded: true,
            isDense: true,
            value: valor,
            onChanged: _carregandoFiltros
                ? null
                : (novo) {
                    if (novo != null) setState(() => aoAlterar(novo));
                  },
            items: [
              DropdownMenuItem(value: '', child: Text(todos)),
              ...opcoes.map((opcao) => DropdownMenuItem(
                    value: opcao,
                    child: Text(rotulo?.call(opcao) ?? opcao),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controles() {
    final filtros = _filtros;
    return Card(
      margin: EdgeInsets.zero,
      color: _fundoCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFD4E0ED)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _seletor(
                  chave: 'reports_period',
                  titulo: 'Período',
                  valor: _periodo,
                  todos: 'Todos os períodos',
                  opcoes: filtros?.periodos ?? const [],
                  rotulo: _rotuloPeriodo,
                  aoAlterar: (valor) => _periodo = valor,
                ),
                _seletor(
                  chave: 'reports_type',
                  titulo: 'Tipo de relatório',
                  valor: _tipo,
                  todos: 'Todos os tipos',
                  opcoes: filtros?.tipos ?? const [],
                  aoAlterar: (valor) => _tipo = valor,
                ),
                _seletor(
                  chave: 'reports_scope',
                  titulo: 'Abrangência',
                  valor: _abrangencia,
                  todos: 'Todas',
                  opcoes: filtros?.abrangencias ?? const [],
                  aoAlterar: (valor) => _abrangencia = valor,
                ),
                SizedBox(
                  width: 205,
                  child: TextField(
                    key: const Key('reports_line'),
                    controller: _linha,
                    onSubmitted: (_) => _aplicarFiltros(),
                    decoration: InputDecoration(
                      labelText: 'Linha de transporte',
                      hintText: 'Ex.: 01',
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  key: const Key('reports_apply'),
                  onPressed: _carregandoPagina ? null : _aplicarFiltros,
                  icon: const Icon(Icons.search, size: 19),
                  label: const Text('Filtrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azulPrincipal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ],
            ),
            if (_carregandoFiltros) ...[
              const SizedBox(height: 12),
              const Text('Carregando filtros...',
                  style: TextStyle(color: _cinzaTexto)),
            ],
            if (_erroFiltros != null) ...[
              const SizedBox(height: 12),
              Text('Filtros indisponíveis: $_erroFiltros',
                  style: const TextStyle(color: Color(0xFFB42318))),
              TextButton(
                onPressed: _carregarFiltros,
                child: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _controlesGerenciais() {
    final intervaloTexto = _intervalo == null
        ? 'Todo o histórico'
        : '${_intervalo!.start.toString().substring(0, 10)} a ${_intervalo!.end.toString().substring(0, 10)}';
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: _granularidade,
              decoration: const InputDecoration(labelText: 'Granularidade'),
              items: const [
                DropdownMenuItem(value: 'diaria', child: Text('Diária')),
                DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                DropdownMenuItem(value: 'mensal', child: Text('Mensal')),
              ],
              onChanged: (valor) {
                if (valor == null) return;
                setState(() => _granularidade = valor);
                _carregarResumo();
              },
            )),
        OutlinedButton.icon(
          onPressed: _selecionarIntervalo,
          icon: const Icon(Icons.date_range),
          label: Text(intervaloTexto),
        ),
      ],
    );
  }

  Widget _botaoExportacao() => FilledButton.icon(
        onPressed: _exportando ? null : _exportarCsv,
        icon: _exportando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.download),
        label: const Text('Exportar CSV dos registros filtrados'),
      );

  String _valor(dynamic valor) {
    if (valor == null) return '—';
    if (valor is Map || valor is List) return jsonEncode(valor);
    return valor.toString();
  }

  String _valorIndicador(String campo, {bool decimal = false}) {
    final valor = _resumo?.indicadores[campo];
    if (valor is! num) return 'N/D';
    return decimal ? valor.toStringAsFixed(2) : valor.round().toString();
  }

  Widget _cartaoIndicador(String titulo, String valor, IconData icone) {
    return SizedBox(
      width: 220,
      child: Card(
        color: _fundoCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFD4E0ED)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icone, color: _azulPrincipal),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(color: _cinzaTexto, fontSize: 12)),
                const SizedBox(height: 5),
                Text(valor,
                    style: const TextStyle(
                        color: _azulEscuro,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _cartoesResumo() {
    if (_resumo?.serie.isEmpty ?? true) {
      return const Card(
          child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('Não há registros para o intervalo selecionado.'),
      ));
    }
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _cartaoIndicador(
          'Quilometragem',
          '${_valorIndicador('quilometragem_km', decimal: true)} km',
          Icons.route),
      _cartaoIndicador('Viagens realizadas',
          _valorIndicador('viagens_realizadas'), Icons.directions_bus),
      _cartaoIndicador('Passageiros pagantes',
          _valorIndicador('passageiros_pagantes'), Icons.people_alt_outlined),
      _cartaoIndicador('Não pagantes',
          _valorIndicador('passageiros_nao_pagantes'), Icons.people_outline),
      _cartaoIndicador(
          'Vendas',
          'R\$ ${_valorIndicador('total_vendas', decimal: true)}',
          Icons.payments_outlined),
      _cartaoIndicador(
          'Utilização financeira',
          'R\$ ${_valorIndicador('total_utilizacao', decimal: true)}',
          Icons.account_balance_wallet_outlined),
      _cartaoIndicador(
          'Saldo final',
          'R\$ ${_valorIndicador('saldo_final', decimal: true)}',
          Icons.account_balance_outlined),
    ]);
  }

  List<FlSpot> _pontos(String campo) {
    final serie = _resumo?.serie ?? const [];
    return [
      for (var i = 0; i < serie.length; i++)
        if ((serie[i]['dias_operacao'] as num? ?? 0) > 0 &&
            serie[i][campo] is num)
          FlSpot(i.toDouble(), (serie[i][campo] as num).toDouble()),
    ];
  }

  Widget _grafico(
      String titulo, List<LineChartBarData> linhas, List<String> legendas) {
    final serie = _resumo?.serie ?? const [];
    if (serie.length < 2) return const SizedBox.shrink();
    return Card(
      color: _fundoCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              style: const TextStyle(
                  color: _azulEscuro,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 14),
          SizedBox(
              height: 230,
              child: LineChart(LineChartData(
                lineBarsData: linhas,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                    showTitles: true,
                    interval: (serie.length / 4)
                        .ceilToDouble()
                        .clamp(1, double.infinity)
                        .toDouble(),
                    reservedSize: 28,
                    getTitlesWidget: (valor, meta) {
                      final indice = valor.toInt();
                      if (indice < 0 ||
                          indice >= serie.length ||
                          valor != indice) {
                        return const SizedBox.shrink();
                      }
                      final rotulo = serie[indice]['periodo']?.toString() ?? '';
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                            rotulo.length > 7 ? rotulo.substring(5) : rotulo,
                            style: const TextStyle(
                                fontSize: 9, color: _cinzaTexto)),
                      );
                    },
                  )),
                  leftTitles: const AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 38)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
              ))),
          Wrap(spacing: 14, children: [
            for (var i = 0; i < linhas.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 12, height: 3, color: linhas[i].color),
                const SizedBox(width: 5),
                Text(legendas[i], style: const TextStyle(fontSize: 11)),
              ]),
          ]),
          Text('Granularidade $_granularidade; ${serie.length} períodos',
              style: const TextStyle(color: _cinzaTexto, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _graficosResumo() {
    final serie = _resumo?.serie ?? const [];
    if (serie.length < 2) return const SizedBox.shrink();
    return Column(children: [
      _grafico(
          'Viagens programadas e realizadas',
          [
            if (_linhaAplicada.isEmpty)
              LineChartBarData(
                  spots: _pontos('viagens_programadas'),
                  color: const Color(0xFF79A9CF),
                  dotData: const FlDotData(show: false),
                  barWidth: 3),
            LineChartBarData(
                spots: _pontos('viagens_realizadas'),
                color: _azulPrincipal,
                dotData: const FlDotData(show: false),
                barWidth: 3),
          ],
          _linhaAplicada.isEmpty
              ? const ['Programadas', 'Realizadas']
              : const ['Realizadas']),
      _grafico('Evolução da quilometragem', [
        LineChartBarData(
            spots: _pontos('quilometragem_km'),
            color: const Color(0xFF00A878),
            dotData: const FlDotData(show: false),
            barWidth: 3),
      ], const [
        'Quilômetros'
      ]),
    ]);
  }

  Widget _alertas() {
    final serie = _resumo?.serie ?? const [];
    final alertas = <String>[];
    for (var i = 1; i < serie.length; i++) {
      final anterior = serie[i - 1];
      final atual = serie[i];
      final viagensAnt = anterior['viagens_realizadas'] as num?;
      final viagensAtu = atual['viagens_realizadas'] as num?;
      final temOperacaoAnt = (anterior['dias_operacao'] as num? ?? 0) > 0;
      final temOperacaoAtu = (atual['dias_operacao'] as num? ?? 0) > 0;
      if (temOperacaoAnt &&
          temOperacaoAtu &&
          viagensAnt != null &&
          viagensAnt > 0 &&
          viagensAtu != null &&
          (viagensAtu - viagensAnt) / viagensAnt <= -0.20) {
        alertas
            .add('Queda de pelo menos 20% nas viagens em ${atual['periodo']}.');
      }
      final kmAnt = anterior['quilometragem_km'] as num?;
      final kmAtu = atual['quilometragem_km'] as num?;
      if (temOperacaoAnt &&
          temOperacaoAtu &&
          kmAnt != null &&
          kmAnt > 0 &&
          kmAtu != null &&
          ((kmAtu - kmAnt) / kmAnt).abs() >= 0.25) {
        alertas.add(
            'Variação de pelo menos 25% na quilometragem em ${atual['periodo']}.');
      }
    }
    return Card(
      color: const Color(0xFFFFF8E8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sinais para análise',
              style: TextStyle(
                  color: _azulEscuro,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
              'Regras iniciais: queda de viagens ≥20% ou variação de km ≥25% frente ao período anterior.',
              style: TextStyle(color: _cinzaTexto, fontSize: 12)),
          const SizedBox(height: 8),
          if (alertas.isEmpty)
            const Text(
                'Nenhum desvio acima dos limites foi encontrado na série atual.')
          else
            ...alertas.map((texto) => Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(children: [
                    const Icon(Icons.warning_amber,
                        color: Color(0xFFB7791F), size: 19),
                    const SizedBox(width: 8),
                    Expanded(child: Text(texto)),
                  ]),
                )),
        ]),
      ),
    );
  }

  Widget _campoDetalhe(MapEntry<String, dynamic> campo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(builder: (context, constraints) {
        final chave = Text(
          campo.key,
          style:
              const TextStyle(fontWeight: FontWeight.w600, color: _azulEscuro),
        );
        final valor = SelectableText(
          _valor(campo.value),
          style: const TextStyle(color: _azulEscuro),
        );
        if (constraints.maxWidth < 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [chave, valor],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 200, child: chave),
            Expanded(child: valor),
          ],
        );
      }),
    );
  }

  Widget _detalhes(String titulo, Map<String, dynamic> campos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _azulEscuro,
            )),
        const SizedBox(height: 8),
        if (campos.isEmpty)
          const Text('Sem campos disponíveis.',
              style: TextStyle(color: _cinzaTexto))
        else
          ...campos.entries.map(_campoDetalhe),
      ],
    );
  }

  bool _passageirosDivergentes(RegistroRelatorio registro) {
    if (registro.categoria != 'passageiros') return false;
    final original = registro.dadosOriginais['Total Passageiros'];
    final tratado = registro.dadosTratados['total_passageiros'];
    if (original is! String || tratado is! num) return false;

    final texto = original.trim().replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d+$|^\d{1,3}(?:\.\d{3})+$').hasMatch(texto)) {
      return false;
    }
    final contagemOriginal = int.tryParse(texto.replaceAll('.', ''));
    if (contagemOriginal == null || !tratado.isFinite) return false;
    return contagemOriginal != tratado;
  }

  Widget _registro(RegistroRelatorio registro) {
    final amostra = registro.dadosOriginais.entries.take(2).toList();
    return Card(
      key: ValueKey('registro_${registro.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: _fundoCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFD4E0ED)),
      ),
      child: ExpansionTile(
        title: Text(
          registro.arquivoOrigem,
          style:
              const TextStyle(fontWeight: FontWeight.w600, color: _azulEscuro),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${registro.categoria} · Tabela ${registro.tabela} · Registro ${registro.linha}',
              style: const TextStyle(color: _cinzaTexto),
            ),
            if (amostra.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                amostra
                    .map((campo) => '${campo.key}: ${_valor(campo.value)}')
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _azulEscuro),
              ),
            ],
            const SizedBox(height: 5),
            const Text('Ver detalhes', style: TextStyle(color: _azulPrincipal)),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          const Divider(),
          if (_passageirosDivergentes(registro)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE2F2FF),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFD4E0ED)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: _azulPrincipal, size: 20),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'A contagem tratada de passageiros difere do valor original.',
                      style: TextStyle(color: _azulEscuro),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _detalhes('Dados originais', registro.dadosOriginais),
          const SizedBox(height: 12),
          _detalhes('Dados tratados', registro.dadosTratados),
        ],
      ),
    );
  }

  Widget _resultados() {
    final pagina = _pagina;
    if (_carregandoPagina && pagina == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_erroPagina != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_erroPagina!,
                  style: const TextStyle(color: Color(0xFFB42318))),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _carregarPagina(pagina?.pagina ?? 1),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (pagina == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_carregandoPagina) const LinearProgressIndicator(),
        Text('${pagina.total} registros encontrados',
            style: const TextStyle(color: _cinzaTexto)),
        const SizedBox(height: 12),
        if (pagina.itens.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'Nenhum registro encontrado para os filtros selecionados.'),
            ),
          )
        else
          ...pagina.itens.map(_registro),
        if (pagina.total > 0) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: _carregandoPagina || pagina.pagina <= 1
                    ? null
                    : () => _carregarPagina(pagina.pagina - 1),
                child: const Text('Anterior'),
              ),
              Text('Página ${pagina.pagina} de ${pagina.paginas}',
                  style: const TextStyle(color: _azulEscuro)),
              OutlinedButton(
                onPressed: _carregandoPagina || pagina.pagina >= pagina.paginas
                    ? null
                    : () => _carregarPagina(pagina.pagina + 1),
                child: const Text('Próxima'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1216),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 30, 16, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Relatórios',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _azulEscuro,
                    )),
                const SizedBox(height: 8),
                const Text(
                    'Consulte os dados importados por período, tipo e linha.',
                    style: TextStyle(color: _cinzaTexto, fontSize: 14)),
                const SizedBox(height: 24),
                const Text('Resumo gerencial',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: _azulEscuro,
                    )),
                const SizedBox(height: 12),
                _controlesGerenciais(),
                const SizedBox(height: 14),
                if (_carregandoResumo)
                  const LinearProgressIndicator()
                else if (_erroResumo != null)
                  Text(_erroResumo!,
                      style: const TextStyle(color: Color(0xFFB42318)))
                else if (_resumo != null) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Pagantes = catraca + antecipados, conforme os campos importados. Confirme a regra de negócio com a SEMOB antes de usar os totais como referência oficial.',
                      style: TextStyle(color: _cinzaTexto, fontSize: 12),
                    ),
                  ),
                  if (_linhaAplicada.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Com filtro por linha, passageiros e valores financeiros não são exibidos porque os relatórios importados não identificam esses dados por linha.',
                        style: TextStyle(color: _cinzaTexto, fontSize: 12),
                      ),
                    ),
                  _cartoesResumo(),
                  const SizedBox(height: 12),
                  _alertas(),
                  const SizedBox(height: 12),
                  _graficosResumo(),
                ],
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Registros detalhados',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: _azulEscuro,
                        )),
                    _botaoExportacao(),
                  ],
                ),
                const SizedBox(height: 12),
                _controles(),
                const SizedBox(height: 24),
                _resultados(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
