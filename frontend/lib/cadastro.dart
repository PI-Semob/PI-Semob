import 'package:flutter/material.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() {
    return _CadastroPageState();
  }
}

class _CadastroPageState extends State<CadastroPage> {
  // Cada variavel guarda o que foi digitado em um campo.
  String nome = '';
  String cpf = '';
  String email = '';
  String celular = '';
  String confirmacaoSenha = '';
  bool esconderSenha = true;
  bool esconderConfirmacao = true;
  bool aceitouTermos = false;
  String senha = '';

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  void cadastrar() {
    // Aceita CPF e celular com ou sem pontuacao.
    String cpfNumeros =
        cpf.replaceAll('.', '').replaceAll('-', '').replaceAll(' ', '');
    String celularNumeros = celular
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');

    // As verificacoes acontecem quando a pessoa clica em Cadastrar.
    if (nome.trim().isEmpty) {
      mostrarMensagem('Informe seu nome completo.');
      return;
    }
    if (cpfNumeros.length != 11 ||
        int.tryParse(cpfNumeros) == null ||
        cpfNumeros.contains('+') ||
        cpfNumeros.contains('-')) {
      mostrarMensagem('Informe um CPF com 11 números.');
      return;
    }
    // Verificacao simples para este exercicio, sem validar um e-mail real.
    if (!email.contains('@') ||
        !email.contains('.') ||
        email.contains(' ') ||
        email.startsWith('@') ||
        email.endsWith('@')) {
      mostrarMensagem('Confira o e-mail digitado.');
      return;
    }
    if (celularNumeros.length != 11 ||
        int.tryParse(celularNumeros) == null ||
        celularNumeros.contains('+') ||
        celularNumeros.contains('-')) {
      mostrarMensagem('Informe o celular com 11 números, incluindo o DDD.');
      return;
    }
    if (senha.length < 8) {
      mostrarMensagem('A senha deve ter pelo menos 8 caracteres.');
      return;
    }
    if (confirmacaoSenha != senha) {
      mostrarMensagem('As senhas precisam ser iguais.');
      return;
    }
    if (!aceitouTermos) {
      mostrarMensagem('Aceite os termos para continuar.');
      return;
    }
    FocusScope.of(context).unfocus();
    mostrarMensagem(
        'O cadastro estará disponível após a integração com o servidor.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 438),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo menor, como na imagem do cadastro.
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 56,
                        height: 56,
                        color: const Color(0xFF0B1F36),
                        child: Stack(children: [
                          const Center(
                              child: Icon(Icons.shield_outlined,
                                  color: Colors.white, size: 26)),
                          Row(children: [
                            Expanded(
                                child: Container(
                                    height: 4, color: const Color(0xFF00A878))),
                            Expanded(
                                child: Container(
                                    height: 4, color: const Color(0xFFFFD600))),
                            Expanded(
                                child: Container(
                                    height: 4, color: const Color(0xFF005BBB))),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('SEMOB',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0B1F36))),
                  const Text('SECRETARIA DE MOBILIDADE URBANA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 9,
                          height: 1.6,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  const Text('Cadastro',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF172554))),
                  const SizedBox(height: 4),
                  const Text(
                      'Cadastre seus dados oficiais para acessar os serviços.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),

                  const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('Nome completo',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF172554)))),
                  TextField(
                    onChanged: (valor) {
                      nome = valor;
                    },
                    decoration: InputDecoration(
                      hintText: 'Seu nome completo',
                      hintStyle: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      prefixIcon: Icon(Icons.person_outline,
                          color: const Color(0xFF64748B), size: 21),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD599)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: Color(0xFF005BBB), width: 2),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF172554)),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('CPF',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF172554)))),
                  TextField(
                    onChanged: (valor) {
                      cpf = valor;
                    },
                    decoration: InputDecoration(
                      hintText: '000.000.000-00',
                      hintStyle: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      prefixIcon: Icon(Icons.badge_outlined,
                          color: const Color(0xFF64748B), size: 21),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD599)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: Color(0xFF005BBB), width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF172554)),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('E-mail',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF172554)))),
                  TextField(
                    onChanged: (valor) {
                      email = valor;
                    },
                    decoration: InputDecoration(
                      hintText: 'seu@email.com',
                      hintStyle: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      prefixIcon: Icon(Icons.mail_outline,
                          color: const Color(0xFF64748B), size: 21),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD599)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: Color(0xFF005BBB), width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF172554)),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('Celular',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF172554)))),
                  TextField(
                    onChanged: (valor) {
                      celular = valor;
                    },
                    decoration: InputDecoration(
                      hintText: '(11) 99999-0000',
                      hintStyle: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      prefixIcon: Icon(Icons.phone_outlined,
                          color: const Color(0xFF64748B), size: 21),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD599)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: Color(0xFF005BBB), width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF172554)),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('Senha',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF172554)))),
                  TextField(
                    obscureText: esconderSenha,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF172554)),
                    onChanged: (valor) {
                      senha = valor;
                    },
                    decoration: InputDecoration(
                      hintText: 'Mínimo 8 caracteres',
                      hintStyle: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      prefixIcon: Icon(Icons.lock_outline,
                          color: const Color(0xFF64748B), size: 21),
                      suffixIcon: IconButton(
                        tooltip:
                            esconderSenha ? 'Mostrar senha' : 'Ocultar senha',
                        icon: Icon(
                            esconderSenha
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                            size: 21),
                        onPressed: () {
                          setState(() {
                            esconderSenha = !esconderSenha;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD599)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: Color(0xFF005BBB), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('Confirmar senha',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF172554)))),
                  TextField(
                    onChanged: (valor) {
                      confirmacaoSenha = valor;
                    },
                    obscureText: esconderConfirmacao,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (valor) {
                      cadastrar();
                    },
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF172554)),
                    decoration: InputDecoration(
                      hintText: 'Repita a senha cadastrada',
                      hintStyle: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      prefixIcon: Icon(Icons.lock_outline,
                          color: const Color(0xFF64748B), size: 21),
                      suffixIcon: IconButton(
                        tooltip: esconderConfirmacao
                            ? 'Mostrar confirmação'
                            : 'Ocultar confirmação',
                        icon: Icon(
                            esconderConfirmacao
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                            size: 21),
                        onPressed: () {
                          setState(() {
                            esconderConfirmacao = !esconderConfirmacao;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD599)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: Color(0xFF005BBB), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: aceitouTermos,
                          activeColor: const Color(0xFF005BBB),
                          onChanged: (valor) {
                            setState(() {
                              aceitouTermos = valor == true;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text.rich(TextSpan(
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF172554)),
                        children: [
                          const TextSpan(text: 'Li e aceito os '),
                          const TextSpan(
                              text: 'Termos de Uso',
                              style: TextStyle(
                                  color: Color(0xFF005BBB),
                                  fontWeight: FontWeight.w700)),
                          const TextSpan(text: ' e a '),
                          const TextSpan(
                              text: 'Política de Privacidade.',
                              style: TextStyle(
                                  color: Color(0xFF005BBB),
                                  fontWeight: FontWeight.w700)),
                        ],
                      ))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: cadastrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005BBB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      elevation: 5,
                      shadowColor: const Color(0x40005BBB),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cadastrar',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Já tem conta?',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF172554))),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF005BBB),
                            padding: const EdgeInsets.symmetric(horizontal: 4)),
                        child: const Text('Faça login',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
