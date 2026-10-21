import 'dart:convert';

import 'package:flutter/material.dart';

import 'reports_service.dart';

const _azulEscuro = Color(0xFF172554);
const _azulPrincipal = Color(0xFF1976B9);
const _cinzaTexto = Color(0xFF667D95);
const _fundoCard = Color(0xFFF8FAFD);

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, this.service, this.revision = 0});

  final RelatoriosService? service;
  final int revision;

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
  bool _carregandoFiltros = true;
  bool _carregandoPagina = true;
  int _ultimaConsulta = 0;
  int _ultimaConsultaFiltros = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RelatoriosService();
    _carregarFiltros();
    _carregarPagina(1);
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

  String _valor(dynamic valor) {
    if (valor == null) return '—';
    if (valor is Map || valor is List) return jsonEncode(valor);
    return valor.toString();
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
