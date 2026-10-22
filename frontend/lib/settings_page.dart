import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class StatusSistema {
  const StatusSistema({
    required this.apiDisponivel,
    required this.bancoDisponivel,
  });

  final bool apiDisponivel;
  final bool bancoDisponivel;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.usuario,
    required this.onLogout,
    this.verificarApi,
  });

  final UsuarioAutenticado usuario;
  final VoidCallback onLogout;
  final Future<StatusSistema> Function()? verificarApi;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<StatusSistema> _status;

  @override
  void initState() {
    super.initState();
    _status = _consultarStatus();
  }

  Future<StatusSistema> _consultarStatus() async {
    if (widget.verificarApi != null) {
      try {
        return await widget.verificarApi!();
      } catch (_) {
        return const StatusSistema(
          apiDisponivel: false,
          bancoDisponivel: false,
        );
      }
    }

    final cliente = http.Client();
    try {
      final resposta = await cliente
          .get(Uri.parse('${ApiConfig.baseUrl}/health'))
          .timeout(const Duration(seconds: 5));
      final corpo = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (corpo is! Map<String, dynamic>) {
        throw const FormatException('Status inválido');
      }
      return StatusSistema(
        apiDisponivel: resposta.statusCode == 200 || resposta.statusCode == 503,
        bancoDisponivel: corpo['banco'] == 'conectado',
      );
    } catch (_) {
      return const StatusSistema(
        apiDisponivel: false,
        bancoDisponivel: false,
      );
    } finally {
      cliente.close();
    }
  }

  void _atualizarStatus() {
    setState(() => _status = _consultarStatus());
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1216),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configurações',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172554),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Informações da conta e conexão com o sistema.',
                style: TextStyle(fontSize: 14, color: Color(0xFF667D95)),
              ),
              const SizedBox(height: 24),
              _cartao(
                titulo: 'Usuário conectado',
                conteudo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _informacao('Nome', widget.usuario.nome),
                    const SizedBox(height: 12),
                    _informacao('E-mail', widget.usuario.email),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _cartao(
                titulo: 'Conexão',
                conteudo: FutureBuilder<StatusSistema>(
                  future: _status,
                  builder: (context, snapshot) {
                    final status = snapshot.data;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _informacao(
                          'API',
                          status == null
                              ? 'Verificando...'
                              : status.apiDisponivel
                                  ? 'Disponível'
                                  : 'Indisponível',
                        ),
                        const SizedBox(height: 12),
                        _informacao(
                          'MongoDB',
                          status == null
                              ? 'Verificando...'
                              : !status.apiDisponivel
                                  ? 'Não verificado'
                                  : status.bancoDisponivel
                                      ? 'Conectado'
                                      : 'Indisponível',
                        ),
                        const SizedBox(height: 12),
                        _informacao('Endereço da API', ApiConfig.baseUrl),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _atualizarStatus,
                          icon: const Icon(Icons.refresh_outlined),
                          label: const Text('Atualizar status'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Sair da conta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4E89),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartao({required String titulo, required Widget conteudo}) {
    return Card(
      color: const Color(0xFFF8FAFD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF172554),
              ),
            ),
            const SizedBox(height: 18),
            conteudo,
          ],
        ),
      ),
    );
  }

  Widget _informacao(String rotulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: const TextStyle(fontSize: 12, color: Color(0xFF667D95)),
        ),
        const SizedBox(height: 3),
        SelectableText(
          valor,
          style: const TextStyle(fontSize: 15, color: Color(0xFF172554)),
        ),
      ],
    );
  }
}
