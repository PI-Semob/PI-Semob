import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  static String get baseUrl {
    const urlConfigurada = String.fromEnvironment('API_BASE_URL');
    if (urlConfigurada.isNotEmpty) {
      return urlConfigurada.replaceFirst(RegExp(r'/$'), '');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }
}

class AuthException implements Exception {
  const AuthException(this.mensagem, {this.statusCode});

  final String mensagem;
  final int? statusCode;

  @override
  String toString() => mensagem;
}

class UsuarioAutenticado {
  const UsuarioAutenticado({
    required this.id,
    required this.nome,
    required this.email,
  });

  final String id;
  final String nome;
  final String email;
}

class LoginResult {
  const LoginResult({required this.mensagem, required this.usuario});

  final String mensagem;
  final UsuarioAutenticado usuario;
}

class AuthService {
  AuthService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<String> cadastrar({
    required String nome,
    required String cpf,
    required String email,
    required String celular,
    required String senha,
  }) async {
    final resposta = await _post('/usuarios', {
      'nome': nome,
      'cpf': cpf,
      'email': email,
      'celular': celular,
      'senha': senha,
    });
    return resposta['mensagem'] as String? ?? 'Usuário criado com sucesso';
  }

  Future<String> login({
    required String email,
    required String senha,
  }) async {
    final resultado = await loginComUsuario(email: email, senha: senha);
    return resultado.mensagem;
  }

  Future<LoginResult> loginComUsuario({
    required String email,
    required String senha,
  }) async {
    final resposta = await _post('/login', {
      'email': email,
      'senha': senha,
    });
    final usuario = resposta['usuario'];
    if (usuario is! Map<String, dynamic> ||
        usuario['id'] is! String ||
        (usuario['id'] as String).isEmpty ||
        usuario['nome'] is! String ||
        (usuario['nome'] as String).isEmpty ||
        usuario['email'] is! String ||
        (usuario['email'] as String).isEmpty) {
      throw const AuthException('Resposta inválida do servidor.');
    }
    return LoginResult(
      mensagem:
          resposta['mensagem'] as String? ?? 'Login realizado com sucesso',
      usuario: UsuarioAutenticado(
        id: usuario['id'] as String,
        nome: usuario['nome'] as String,
        email: usuario['email'] as String,
      ),
    );
  }

  Future<Map<String, dynamic>> _post(
    String caminho,
    Map<String, String> dados,
  ) async {
    late http.Response resposta;

    try {
      resposta = await _client
          .post(
            Uri.parse('$_baseUrl$caminho'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(dados),
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const AuthException('O servidor demorou para responder.');
    } on http.ClientException {
      throw const AuthException('Não foi possível conectar ao servidor.');
    }

    final corpo = _decodificarResposta(utf8.decode(resposta.bodyBytes));
    if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
      return corpo;
    }

    throw AuthException(
      _mensagemDeErro(resposta.statusCode, corpo),
      statusCode: resposta.statusCode,
    );
  }

  Map<String, dynamic> _decodificarResposta(String corpo) {
    if (corpo.isEmpty) {
      return {};
    }

    try {
      final conteudo = jsonDecode(corpo);
      if (conteudo is Map<String, dynamic>) {
        return conteudo;
      }
    } on FormatException {
      return {};
    }

    return {};
  }

  String _mensagemDeErro(int statusCode, Map<String, dynamic> corpo) {
    final detalhe = corpo['detail'];
    if (detalhe is String && detalhe.isNotEmpty) {
      return detalhe;
    }

    final mensagem = corpo['mensagem'];
    if (mensagem is String && mensagem.isNotEmpty) {
      return mensagem;
    }

    if (statusCode == 401) {
      return 'E-mail ou senha inválidos';
    }
    if (statusCode == 409) {
      return 'E-mail já cadastrado';
    }
    if (statusCode == 400 || statusCode == 422) {
      return 'Confira os dados informados.';
    }
    return 'Não foi possível concluir a solicitação.';
  }
}
