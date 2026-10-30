import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'dashboard_page.dart';
import 'login.dart';
import 'operation_page.dart';
import 'reports_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.usuario,
    this.accessToken,
    this.authService,
    this.dashboardPage,
    this.reportsPage,
  });

  final UsuarioAutenticado usuario;
  final String? accessToken;
  final AuthService? authService;
  final Widget? dashboardPage;
  final Widget? reportsPage;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _secaoAtual = 0;
  int _revisaoDados = 0;
  final Set<int> _secoesVisitadas = {0};
  final _formSenha = GlobalKey<FormState>();

  void _dadosImportados() {
    setState(() => _revisaoDados++);
  }

  void _abrirSecao(int secao) {
    Navigator.of(context).pop();
    if (_secaoAtual == secao) return;
    setState(() {
      _secaoAtual = secao;
      _secoesVisitadas.add(secao);
    });
  }

  Future<void> _sair() async {
    await (widget.authService ?? AuthService()).limparSessao();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(authService: widget.authService),
      ),
      (_) => false,
    );
  }

  Future<void> _alterarSenha() async {
    final senhaAtual = TextEditingController();
    final novaSenha = TextEditingController();
    var carregando = false;

    try {
      final alterada = await showDialog<bool>(
        context: context,
        builder: (contexto) => StatefulBuilder(
          builder: (contexto, atualizarDialogo) => AlertDialog(
            title: const Text('Alterar senha'),
            content: Form(
              key: _formSenha,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: senhaAtual,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha atual'),
                    validator: (valor) => valor == null || valor.isEmpty
                        ? 'Digite sua senha atual.'
                        : null,
                  ),
                  TextFormField(
                    controller: novaSenha,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nova senha'),
                    validator: (valor) => valor == null || valor.length < 8
                        ? 'A nova senha deve ter pelo menos 8 caracteres.'
                        : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    carregando ? null : () => Navigator.of(contexto).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: carregando
                    ? null
                    : () async {
                        if (!_formSenha.currentState!.validate()) return;
                        atualizarDialogo(() => carregando = true);
                        try {
                          await (widget.authService ?? AuthService())
                              .alterarSenha(
                            accessToken: widget.accessToken ?? '',
                            senhaAtual: senhaAtual.text,
                            novaSenha: novaSenha.text,
                          );
                          if (contexto.mounted) {
                            Navigator.of(contexto).pop(true);
                          }
                        } on AuthException catch (erro) {
                          if (!contexto.mounted) return;
                          atualizarDialogo(() => carregando = false);
                          ScaffoldMessenger.of(contexto).showSnackBar(
                            SnackBar(content: Text(erro.mensagem)),
                          );
                        } catch (_) {
                          if (!contexto.mounted) return;
                          atualizarDialogo(() => carregando = false);
                          ScaffoldMessenger.of(contexto).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Não foi possível alterar a senha.'),
                            ),
                          );
                        }
                      },
                child: carregando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      );
      if (alterada == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha alterada com sucesso.')),
        );
      }
    } finally {
      senhaAtual.dispose();
      novaSenha.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDFE9F5),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              _itemMenu(0, Icons.dashboard_outlined, 'Dashboard'),
              _itemMenu(1, Icons.directions_bus_outlined, 'Operação'),
              _itemMenu(2, Icons.analytics_outlined, 'Relatórios'),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _cabecalho(),
            Expanded(
              child: IndexedStack(
                index: _secaoAtual,
                children: [
                  widget.dashboardPage ??
                      DashboardPage(
                        accessToken: widget.accessToken,
                        revision: _revisaoDados,
                      ),
                  _secoesVisitadas.contains(1)
                      ? OperationPage(onDataImported: _dadosImportados)
                      : const SizedBox.shrink(),
                  _secoesVisitadas.contains(2)
                      ? widget.reportsPage ??
                          ReportsPage(
                            revision: _revisaoDados,
                            accessToken: widget.accessToken,
                          )
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemMenu(int indice, IconData icone, String titulo) {
    return ListTile(
      leading: Icon(icone),
      title: Text(titulo),
      selected: _secaoAtual == indice,
      selectedTileColor: const Color(0xFFE2F2FF),
      selectedColor: const Color(0xFF173F68),
      onTap: () => _abrirSecao(indice),
    );
  }

  Widget _cabecalho() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF173F68),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) {
                  return IconButton(
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                    icon: const Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: 28,
                    ),
                  );
                },
              ),
              const SizedBox(width: 2),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEMOB',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Mobilidade Urbana',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB8CCE0),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções da conta',
                onSelected: (opcao) {
                  if (opcao == 'senha') _alterarSenha();
                  if (opcao == 'sair') _sair();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'senha',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.lock_outline),
                      title: Text('Alterar Senha'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sair',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout),
                      title: Text('Sair (Logout)'),
                    ),
                  ),
                ],
                child: const CircleAvatar(
                  radius: 21,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person_outline,
                    color: Color(0xFF1976B9),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
