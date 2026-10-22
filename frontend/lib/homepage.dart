import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'dashboard_page.dart';
import 'login.dart';
import 'operation_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.usuario,
    this.authService,
    this.verificarApi,
    this.dashboardPage,
    this.reportsPage,
  });

  final UsuarioAutenticado usuario;
  final AuthService? authService;
  final Future<StatusSistema> Function()? verificarApi;
  final Widget? dashboardPage;
  final Widget? reportsPage;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _secaoAtual = 0;
  int _revisaoDados = 0;
  final Set<int> _secoesVisitadas = {0};

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

  void _sair() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(authService: widget.authService),
      ),
      (_) => false,
    );
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
              _itemMenu(3, Icons.settings_outlined, 'Configurações'),
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
                      DashboardPage(revision: _revisaoDados),
                  _secoesVisitadas.contains(1)
                      ? OperationPage(onDataImported: _dadosImportados)
                      : const SizedBox.shrink(),
                  _secoesVisitadas.contains(2)
                      ? widget.reportsPage ??
                          ReportsPage(revision: _revisaoDados)
                      : const SizedBox.shrink(),
                  _secoesVisitadas.contains(3)
                      ? SettingsPage(
                          usuario: widget.usuario,
                          onLogout: _sair,
                          verificarApi: widget.verificarApi,
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
              const CircleAvatar(
                radius: 21,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person_outline,
                  color: Color(0xFF1976B9),
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
