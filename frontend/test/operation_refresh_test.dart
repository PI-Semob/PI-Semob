import 'dart:convert';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:semob_frontend/import_service.dart';
import 'package:semob_frontend/operation_page.dart';

void main() {
  for (final inseridos in [2, 0]) {
    testWidgets(
      inseridos > 0
          ? 'nova importação avisa para atualizar consultas'
          : 'ZIP duplicado preserva resultado sem atualizar consultas',
      (tester) async {
        var atualizacoes = 0;
        final cliente = MockClient((_) async => http.Response(
            jsonEncode({
              'arquivo': 'dados.zip',
              'arquivos_processados': 1,
              'arquivos_rejeitados': 0,
              'inseridos': inseridos,
              'ignorados': inseridos == 0 ? 2 : 0,
              'rejeitados': 0,
              'detalhes': <Object>[],
            }),
            200));
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: OperationPage(
              service: ImportacaoService(
                client: cliente,
                baseUrl: 'http://localhost:8000',
              ),
              onDataImported: () => atualizacoes++,
            ),
          ),
        ));

        final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
        dropTarget.onDragDone!(DropDoneDetails(
          files: [
            DropItemFile.fromData(
              Uint8List.fromList([1, 2, 3]),
              name: 'dados.zip',
              path: 'dados.zip',
            )
          ],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ));
        await tester.pumpAndSettle();

        expect(atualizacoes, inseridos > 0 ? 1 : 0);
        expect(find.textContaining('Registros inseridos: $inseridos'),
            findsOneWidget);
      },
    );
  }

  testWidgets('falha após inserções parciais também atualiza consultas',
      (tester) async {
    var atualizacoes = 0;
    final cliente = MockClient((_) async => http.Response(
        jsonEncode({
          'detail': {
            'mensagem': 'Falha ao gravar lote',
            'resultado': {
              'inseridos': 3,
              'ignorados': 0,
              'rejeitados': 0,
            },
          },
        }),
        503));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OperationPage(
          service: ImportacaoService(
            client: cliente,
            baseUrl: 'http://localhost:8000',
          ),
          onDataImported: () => atualizacoes++,
        ),
      ),
    ));

    tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
      DropDoneDetails(
        files: [
          DropItemFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            path: 'dados.zip',
          )
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();

    expect(atualizacoes, 1);
    expect(find.textContaining('Inseridos: 3'), findsOneWidget);
  });
}
