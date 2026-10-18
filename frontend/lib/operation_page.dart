import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'import_service.dart';

class OperationPage extends StatefulWidget {
  const OperationPage({super.key, this.onDataImported, this.service});

  final VoidCallback? onDataImported;
  final ImportacaoService? service;

  @override
  State<OperationPage> createState() => _OperationPageState();
}

class _OperationPageState extends State<OperationPage> {
  late final ImportacaoService _servico;
  bool _arrastando = false;
  bool _importando = false;
  double? _progresso;
  String? _erro;
  String? _nomeArquivo;
  ResultadoImportacao? _resultado;

  @override
  void initState() {
    super.initState();
    _servico = widget.service ?? ImportacaoService();
  }

  Future<void> _selecionarArquivo() async {
    if (_importando) return;
    try {
      final escolha = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withReadStream: true,
      );
      if (escolha == null || escolha.files.isEmpty) return;
      final arquivo = escolha.files.single;
      Stream<List<int>>? conteudo = arquivo.readStream;
      if (conteudo == null && arquivo.bytes != null) {
        conteudo = Stream.value(arquivo.bytes!);
      }
      if (conteudo == null && arquivo.path != null) {
        conteudo = XFile(arquivo.path!).openRead();
      }
      if (conteudo == null) {
        setState(() => _erro = 'Não foi possível ler o arquivo selecionado.');
        return;
      }
      await _importar(arquivo.name, arquivo.size, conteudo);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível selecionar o arquivo.');
      }
    }
  }

  Future<void> _receberArquivos(List<XFile> arquivos) async {
    if (_importando) return;
    setState(() => _arrastando = false);
    if (arquivos.length != 1) {
      setState(() => _erro = 'Arraste apenas um arquivo ZIP por vez.');
      return;
    }
    final arquivo = arquivos.single;
    try {
      await _importar(arquivo.name, await arquivo.length(), arquivo.openRead());
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível ler o arquivo arrastado.');
      }
    }
  }

  Stream<List<int>> _acompanharEnvio(
      Stream<List<int>> conteudo, int tamanho) async* {
    var enviados = 0;
    await for (final bloco in conteudo) {
      enviados += bloco.length;
      if (mounted) {
        setState(() => _progresso = enviados / tamanho);
      }
      yield bloco;
    }
    if (mounted) setState(() => _progresso = null);
  }

  Future<void> _importar(
      String nome, int tamanho, Stream<List<int>> conteudo) async {
    if (!nome.toLowerCase().endsWith('.zip')) {
      setState(() => _erro = 'Selecione um arquivo ZIP.');
      return;
    }
    if (tamanho == 0 || tamanho > 50 * 1024 * 1024) {
      setState(() => _erro = 'O ZIP deve ter entre 1 byte e 50 MB.');
      return;
    }

    setState(() {
      _importando = true;
      _progresso = 0;
      _erro = null;
      _resultado = null;
      _nomeArquivo = nome;
    });
    try {
      final resultado = await _servico.importar(
        nome: nome,
        tamanho: tamanho,
        conteudo: _acompanharEnvio(conteudo, tamanho),
      );
      if (mounted) {
        setState(() => _resultado = resultado);
        if (resultado.inseridos > 0) widget.onDataImported?.call();
      }
    } on ImportacaoException catch (erro) {
      if (mounted) {
        setState(() => _erro = erro.mensagem);
        if (erro.inseridosParcial > 0) widget.onDataImported?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Falha inesperada ao importar o arquivo.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _importando = false;
          _progresso = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1216,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Importe dados do transporte',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172554),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Envie o ZIP de relatórios para converter e salvar os registros automaticamente.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF667D95),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 27),
                DropTarget(
                  onDragEntered: (_) => setState(() => _arrastando = true),
                  onDragExited: (_) => setState(() => _arrastando = false),
                  onDragDone: (detalhes) => _receberArquivos(detalhes.files),
                  child: CustomPaint(
                    foregroundPainter: DashedBorderPainter(),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(
                        minHeight: 290,
                      ),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _arrastando
                            ? const Color(0xFFE2F2FF)
                            : const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_upload_outlined,
                            size: 42,
                            color: Color(0xFF1976B9),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Arraste seu arquivo ZIP aqui',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF172554),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'ou',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF667D95),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _importando ? null : _selecionarArquivo,
                            icon: const Icon(
                              Icons.folder_open_outlined,
                              size: 20,
                            ),
                            label: const Text('Selecionar arquivo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976B9),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'ⓘ Formato aceito: ZIP com relatórios HTML · Tamanho máximo: 50 MB',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF667D95),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_importando) ...[
                  Text(
                    _progresso == null
                        ? 'Processando $_nomeArquivo e salvando no MongoDB...'
                        : 'Enviando $_nomeArquivo: ${(_progresso! * 100).round()}%',
                    style: const TextStyle(color: Color(0xFF172554)),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: _progresso),
                  const SizedBox(height: 18),
                ],
                if (_erro != null) ...[
                  Text(_erro!,
                      style: const TextStyle(color: Color(0xFFB42318))),
                  const SizedBox(height: 18),
                ],
                if (_resultado != null) _painelResultado(_resultado!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _painelResultado(ResultadoImportacao resultado) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Importação de ${resultado.arquivo}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Arquivos processados: ${resultado.arquivosProcessados} · '
                'Arquivos rejeitados: ${resultado.arquivosRejeitados}'),
            Text('Registros inseridos: ${resultado.inseridos} · '
                'Ignorados por duplicidade: ${resultado.ignorados} · '
                'Rejeitados: ${resultado.rejeitados}'),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Detalhes por arquivo'),
              children: resultado.detalhes.map((detalhe) {
                final avisos =
                    (detalhe['avisos'] as List<dynamic>? ?? []).join('; ');
                return ListTile(
                  title: Text(detalhe['arquivo'] as String? ?? ''),
                  subtitle: Text(
                    '${detalhe['categoria']}: ${detalhe['inseridos']} inseridos, '
                    '${detalhe['ignorados']} ignorados, '
                    '${detalhe['rejeitados']} rejeitados'
                    '${avisos.isEmpty ? '' : '\n$avisos'}',
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1976B9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(18),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        final end = (distance + 12).clamp(
          0.0,
          metric.length,
        );

        canvas.drawPath(
          metric.extractPath(
            distance,
            end,
          ),
          paint,
        );

        distance += 21;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
