import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capture test', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          body: Center(
            child: Container(
              color: Colors.blue,
              width: 200,
              height: 200,
              child: const Center(
                child: Text('Teste', style: TextStyle(color: Colors.white, fontSize: 24)),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    File('test_capture.png').writeAsBytesSync(byteData!.buffer.asUint8List());
    expect(File('test_capture.png').existsSync(), isTrue);
  });
}
