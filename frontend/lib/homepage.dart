import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDFE9F5),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.dashboard_outlined),
                title: Text('Dashboard'),
              ),
              const ListTile(
                leading: Icon(Icons.directions_bus_outlined),
                title: Text('Operação'),
              ),
              const ListTile(
                leading: Icon(Icons.analytics_outlined),
                title: Text('Relatórios'),
              ),
              const ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('Configurações'),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
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
                        CircleAvatar(
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
              ),
              Padding(
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
                          'Gerencie seu dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF172554),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tenha os principais dados da operação do transporte público em um só lugar.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF667D95),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 27),
                        CustomPaint(
                          foregroundPainter: DashedBorderPainter(),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(
                              minHeight: 290,
                            ),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFD),
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
                                  'Arraste seu dashboard aqui',
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
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'A seleção de arquivos será conectada ao dashboard.',
                                        ),
                                      ),
                                    );
                                  },
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
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'ⓘ Formatos aceitos: PDF, PNG ou JPG · Tamanho máximo: 20 MB',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF667D95),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
