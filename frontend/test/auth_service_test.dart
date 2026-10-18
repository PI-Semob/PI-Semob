import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:semob_frontend/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('usa a URL local e envia o contrato JSON de POST /login', () async {
    http.Request? pedidoRecebido;
    final servico = AuthService(client: MockClient((pedido) async {
      pedidoRecebido = pedido;
      return http.Response(
        jsonEncode({
          'mensagem': 'Login realizado com sucesso',
          'usuario': {
            'id': 'abc',
            'nome': 'Teste',
            'email': 'teste@example.com'
          },
        }),
        200,
      );
    }));

    final mensagem =
        await servico.login(email: 'teste@example.com', senha: 'senha123');

    expect(ApiConfig.baseUrl, 'http://127.0.0.1:8000');
    expect(pedidoRecebido?.method, 'POST');
    expect(pedidoRecebido?.url.toString(), 'http://127.0.0.1:8000/login');
    expect(jsonDecode(pedidoRecebido!.body), {
      'email': 'teste@example.com',
      'senha': 'senha123',
    });
    expect(mensagem, 'Login realizado com sucesso');
  });

  test('retorna o usuário real do login para a sessão da interface', () async {
    final servico = AuthService(
      client: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'mensagem': 'Login realizado com sucesso',
              'usuario': {
                'id': 'abc',
                'nome': 'Usuária Teste',
                'email': 'teste@example.com',
              },
            })),
            200,
          )),
    );

    final resultado = await servico.loginComUsuario(
      email: 'teste@example.com',
      senha: 'senha123',
    );

    expect(resultado.usuario.id, 'abc');
    expect(resultado.usuario.nome, 'Usuária Teste');
    expect(resultado.usuario.email, 'teste@example.com');
  });

  test('preserva mensagem UTF-8 e status 401 para credenciais inválidas',
      () async {
    final servico = AuthService(
      client: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({'detail': 'E-mail ou senha inválidos'})),
            401,
            headers: {'content-type': 'application/json'},
          )),
      baseUrl: 'http://127.0.0.1:8000',
    );

    await expectLater(
      servico.login(email: 'inexistente@example.com', senha: 'incorreta'),
      throwsA(isA<AuthException>()
          .having((erro) => erro.statusCode, 'status', 401)
          .having((erro) => erro.mensagem, 'mensagem',
              'E-mail ou senha inválidos')),
    );
  });

  test('não aceita resposta 200 sem usuário autenticado', () async {
    final servico = AuthService(
      client: MockClient((_) async => http.Response('{"mensagem":"ok"}', 200)),
      baseUrl: 'http://127.0.0.1:8000',
    );

    await expectLater(
      servico.login(email: 'teste@example.com', senha: 'senha123'),
      throwsA(isA<AuthException>()),
    );
  });

  test('informa indisponibilidade de conexão', () async {
    final servico = AuthService(
      client:
          MockClient((_) async => throw http.ClientException('sem conexão')),
      baseUrl: 'http://127.0.0.1:8000',
    );

    await expectLater(
      servico.login(email: 'teste@example.com', senha: 'senha123'),
      throwsA(isA<AuthException>().having(
        (erro) => erro.mensagem,
        'mensagem',
        'Não foi possível conectar ao servidor.',
      )),
    );
  });
}
