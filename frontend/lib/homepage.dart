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

  void _abrirSecao(int secao, {bool fecharDrawer = false}) {
    if (fecharDrawer) {
      Navigator.of(context).pop();
    }
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
    final largura = MediaQuery.sizeOf(context).width;
    final desktop = largura >= 860;
    return Scaffold(
      backgroundColor: const Color(0xFFDFE9F5),
      drawer: desktop ? null : Drawer(
        child: SafeArea(
          child: Column(
            children: [
              _itemMenu(0, Icons.dashboard_outlined, 'Dashboard'),
              _itemMenu(1, Icons.directions_bus_outlined, 'Importação'),
              _itemMenu(2, Icons.analytics_outlined, 'Relatórios'),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _cabecalho(desktop),
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
      title: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      iconColor: const Color(0xFF173F68),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      minVerticalPadding: 14,
      visualDensity: const VisualDensity(vertical: 1),
      selected: _secaoAtual == indice,
      selectedTileColor: const Color(0xFFE2F2FF),
      selectedColor: const Color(0xFF173F68),
      onTap: () => _abrirSecao(indice, fecharDrawer: true),
    );
  }

  Widget _cabecalho(bool desktop) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF173F68),
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 32 : 12,
        vertical: desktop ? 8 : 10,
      ),
      child: desktop
          ? SizedBox(
              height: 104,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/images/logo.png', width: 56, height: 56, fit: BoxFit.contain),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('SEMOB', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                            SizedBox(height: 3),
                            Text('Mobilidade Urbana', style: TextStyle(fontSize: 12, color: Color(0xFFB8CCE0))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _menuConta(true),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _topico(0, Icons.dashboard_outlined, 'Dashboard', desktop: true),
                        const SizedBox(width: 10),
                        _topico(1, Icons.directions_bus_outlined, 'Importação', desktop: true),
                        const SizedBox(width: 10),
                        _topico(2, Icons.analytics_outlined, 'Relatórios', desktop: true),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'Abrir menu',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 48,
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 48,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('SEMOB', style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    )),
                    SizedBox(height: 3),
                    Text('Mobilidade Urbana', style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB8CCE0),
                    )),
                  ],
                ),
                const Spacer(),
                _menuConta(false),
              ],
            ),
    );
  }

  Widget _menuConta(bool desktop) {
    return PopupMenuButton<String>(
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
      child: SizedBox(
        width: desktop ? 56 : 48,
        height: desktop ? 56 : 48,
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: const Icon(Icons.person_outline,
              color: Color(0xFF1976B9), size: 23),
        ),
      ),
    );
  }

  Widget _topico(
    int indice,
    IconData icone,
    String titulo, {
    bool desktop = false,
  }) {
    final ativo = _secaoAtual == indice;
    return TextButton.icon(
      onPressed: () => _abrirSecao(indice),
      style: TextButton.styleFrom(
        foregroundColor: ativo ? Colors.white : const Color(0xFFCFDDEC),
        backgroundColor:
            ativo ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: desktop ? 24 : 20,
          vertical: desktop ? 16 : 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icone, size: desktop ? 25 : 22),
      label: Text(titulo, style: TextStyle(
        fontSize: desktop ? 18 : 16,
        fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
      )),
    );
  }
}
