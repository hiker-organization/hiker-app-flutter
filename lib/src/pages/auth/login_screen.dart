import 'package:app_hiker/components/login_form.dart';
import 'package:app_hiker/components/social_button.dart';
import 'package:app_hiker/components/submit_button.dart';
import 'package:app_hiker/src/services/auth_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.navigate('/app');
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(
        () => _errorMessage = 'Erro ao conectar com o servidor $e.message',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/img/logo.png', width: 200, height: 200),
                    const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SocialButton(
                      iconName: 'google',
                      label: 'Entrar com Google',
                      onPressed: () {
                        // Handle Google sign-in
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ou',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    LoginForm(hintText: 'Email', controller: _emailController),
                    const SizedBox(height: 10),
                    LoginForm(
                      hintText: 'Senha',
                      obscureText: !_showPassword,
                      controller: _passwordController,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Pallete.whiteColor,
                        ),
                        onPressed: () {
                          setState(() => _showPassword = !_showPassword);
                        },
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Esqueceu a senha? ',
                          style: TextStyle(
                            fontSize: 16,
                            color: Pallete.whiteColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.pushNamed(
                            '/forgot-password',
                            arguments: _emailController.text.trim(),
                          ),
                          child: const Text(
                            'Clique aqui',
                            style: TextStyle(
                              fontSize: 16,
                              color: Pallete.whiteColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: 312,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          "E-mail ou senha incorretos. Tente novamente.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Pallete.errorColor),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SubmitButton(
                      label: 'Entrar',
                      isLoading: _isLoading,
                      onPressed: handleLogin,
                      horizontalPadding: 130,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Não tem uma conta? ',
                          style: TextStyle(
                            fontSize: 16,
                            color: Pallete.whiteColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.pushNamed('/register'),
                          child: const Text(
                            'Cadastre-se',
                            style: TextStyle(
                              fontSize: 16,
                              color: Pallete.whiteColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
