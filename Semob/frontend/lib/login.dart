import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cadastro.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() {
    return _LoginPageState();
  }
}

class _LoginPageState extends State<LoginPage> {
  // Permite verificar os campos do formulário.
  final chaveFormulario = GlobalKey<FormState>();

  // A senha começa escondida.
  bool esconderSenha = true;

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  void entrar() {
    if (!chaveFormulario.currentState!.validate()) {
      return;
    }

    // Fecha o teclado.
    FocusScope.of(context).unfocus();

    // O login ainda precisa ser conectado ao servidor.
    mostrarMensagem(
      'O acesso estará disponível após a integração com o servidor.',
    );
  }

  // Aparência usada nos campos de e-mail e senha.
  InputDecoration decoracaoCampo(
    String dica,
    IconData icone, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: dica,
      hintStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 14,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      prefixIcon: Icon(
        icone,
        color: const Color(0xFF64748B),
        size: 21,
      ),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(
          color: Color(0xFFCBD599),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(
          color: Color(0xFF005BBB),
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define as cores das barras do celular.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            // Limita a largura em telas grandes.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 438),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
                child: AutofillGroup(
                  child: Form(
                    key: chaveFormulario,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo e nome da secretaria.
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                width: 72,
                                height: 72,
                                color: const Color(0xFF0B1F36),
                                child: Stack(
                                  children: [
                                    const Positioned.fill(
                                      child: Center(
                                        child: Icon(
                                          Icons.shield_outlined,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 4,
                                              color: const Color(0xFF00A878),
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(
                                              height: 4,
                                              color: const Color(0xFFFFD600),
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(
                                              height: 4,
                                              color: const Color(0xFF005BBB),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'SEMOB',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0B1F36),
                              ),
                            ),
                            const Text(
                              'SECRETARIA DE MOBILIDADE URBANA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                height: 1.6,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 36),

                        // Título e descrição.
                        const Text(
                          'Login',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF172554),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Acesse sua conta do portal de mobilidade para\n'
                          'gerenciar seus cartões e benefícios.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.25,
                            color: Color(0xFF64748B),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Campo de e-mail.
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'E-mail',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF172554),
                            ),
                          ),
                        ),
                        TextFormField(
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          autocorrect: false,
                          style: const TextStyle(
                            color: Color(0xFF172554),
                            fontSize: 14,
                          ),
                          decoration: decoracaoCampo(
                            'exemplo@email.com',
                            Icons.person_outline,
                          ),
                          validator: (valor) {
                            String email = '';

                            if (valor != null) {
                              email = valor.trim();
                            }

                            // Confere o formato, como nome@site.com.
                            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(email)) {
                              return 'Informe um e-mail válido.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Campo de senha.
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'Senha',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF172554),
                            ),
                          ),
                        ),
                        TextFormField(
                          obscureText: esconderSenha,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (valor) {
                            entrar();
                          },
                          style: const TextStyle(
                            color: Color(0xFF172554),
                            fontSize: 14,
                          ),
                          decoration: decoracaoCampo(
                            'Digite sua senha',
                            Icons.lock_outline,
                            suffixIcon: IconButton(
                              tooltip: esconderSenha
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: () {
                                setState(() {
                                  esconderSenha = !esconderSenha;
                                });
                              },
                              icon: Icon(
                                esconderSenha
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF64748B),
                                size: 21,
                              ),
                            ),
                          ),
                          validator: (valor) {
                            if (valor == null || valor.isEmpty) {
                              return 'Informe sua senha.';
                            }

                            return null;
                          },
                        ),

                        // Recuperação de senha.
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF005BBB),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () {
                              mostrarMensagem(
                                'A recuperação de senha ainda não está disponível.',
                              );
                            },
                            child: const Text(
                              'Esqueceu a senha?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Botão de entrada.
                        ElevatedButton(
                          onPressed: entrar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005BBB),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                            elevation: 5,
                            shadowColor: const Color(0x40005BBB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Entrar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Texto abaixo do botão.
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 15,
                              color: Color(0xFF00A878),
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Ambiente de login oficial e seguro',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Link de cadastro.
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Não tem conta?',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF172554),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return const CadastroPage();
                                    },
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF005BBB),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                              child: const Text(
                                'Cadastre-se',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
