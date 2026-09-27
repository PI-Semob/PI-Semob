import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:semob_frontend/auth_service.dart';

void main() {
  test('cadastro envia os cinco campos e retorna a mensagem da API', () async {
    final cliente = MockClient((requisicao) async {
      expect(requisicao.method, 'POST');
      expect(requisicao.url.toString(), 'http://api.test/usuarios');
      expect(jsonDecode(requisicao.body), {
        'nome': 'Rafael Palumbo',
        'cpf': '12345678901',
        'email': 'rafa@email.com',
        'celular': '11999999999',
        'senha': '12345678',
      });
      return http.Response(
        jsonEncode({'mensagem': 'Usuário criado com sucesso'}),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final servico = AuthService(
      client: cliente,
      baseUrl: 'http://api.test',
    );

    final mensagem = await servico.cadastrar(
      nome: 'Rafael Palumbo',
      cpf: '12345678901',
      email: 'rafa@email.com',
      celular: '11999999999',
      senha: '12345678',
    );

    expect(mensagem, 'Usuário criado com sucesso');
  });

  test('login transforma o erro 401 em mensagem exibível', () async {
    final cliente = MockClient((requisicao) async {
      return http.Response(
        jsonEncode({'detail': 'E-mail ou senha inválidos'}),
        401,
        headers: {'content-type': 'application/json'},
      );
    });
    final servico = AuthService(
      client: cliente,
      baseUrl: 'http://api.test',
    );

    await expectLater(
      servico.login(email: 'rafa@email.com', senha: 'errada'),
      throwsA(
        isA<AuthException>()
            .having((erro) => erro.statusCode, 'statusCode', 401)
            .having(
              (erro) => erro.mensagem,
              'mensagem',
              'E-mail ou senha inválidos',
            ),
      ),
    );
  });
}
