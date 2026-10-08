import 'package:app_hiker/components/code_input.dart';
import 'package:app_hiker/components/login_form.dart';
import 'package:app_hiker/components/submit_button.dart';
import 'package:app_hiker/src/services/auth_service.dart';
import 'package:app_hiker/src/services/email_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

enum _Step { email, code, newPassword }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailService = EmailService();
  final _authService = AuthService();

  late final _emailController = TextEditingController(text: widget.initialEmail);
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  var _step = _Step.email;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> handleSendEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _emailService.forgotPassword(email: _emailController.text.trim());
      setState(() => _step = _Step.code);
    } on EmailServiceException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Erro ao conectar com o servidor');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> handleConfirmCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.verifyResetCode(
        email: _emailController.text.trim(),
        token: _codeController.text.trim(),
      );
      setState(() => _step = _Step.newPassword);
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Erro ao conectar com o servidor');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> handleResetPassword() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'As senhas não coincidem');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.resetPassword(
        email: _emailController.text.trim(),
        token: _codeController.text.trim(),
        senha: _passwordController.text,
      );
      if (mounted) context.navigate('/login');
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Erro ao conectar com o servidor');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _title {
    switch (_step) {
      case _Step.email:
        return 'Esqueceu a senha?';
      case _Step.code:
        return 'Digite o código';
      case _Step.newPassword:
        return 'Nova senha';
    }
  }

  String get _buttonLabel {
    switch (_step) {
      case _Step.email:
        return 'Enviar código';
      case _Step.code:
        return 'Confirmar código';
      case _Step.newPassword:
        return 'Redefinir senha';
    }
  }

  VoidCallback get _onSubmit {
    switch (_step) {
      case _Step.email:
        return handleSendEmail;
      case _Step.code:
        return handleConfirmCode;
      case _Step.newPassword:
        return handleResetPassword;
    }
  }

  List<Widget> get _stepFields {
    switch (_step) {
      case _Step.email:
        return [LoginForm(hintText: 'Email', controller: _emailController)];
      case _Step.code:
        return [
          Text(
            'Enviamos um código para ${_emailController.text}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Pallete.whiteColor),
          ),
          const SizedBox(height: 10),
          CodeInput(controller: _codeController),
        ];
      case _Step.newPassword:
        return [
          LoginForm(
            hintText: 'Nova senha',
            obscureText: !_showPassword,
            controller: _passwordController,
            suffixIcon: IconButton(
              icon: const Icon(Icons.visibility_off, color: Pallete.whiteColor),
              onPressed: () {
                setState(() => _showPassword = !_showPassword);
              },
            ),
          ),
          const SizedBox(height: 10),
          LoginForm(
            hintText: 'Confirme sua nova senha',
            obscureText: !_showConfirmPassword,
            controller: _confirmPasswordController,
            suffixIcon: IconButton(
              icon: const Icon(Icons.visibility_off, color: Pallete.whiteColor),
              onPressed: () {
                setState(() => _showConfirmPassword = !_showConfirmPassword);
              },
            ),
          ),
        ];
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
                    Text(
                      _title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._stepFields,
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
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Pallete.errorColor),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Lembrou da senha? ',
                          style: TextStyle(
                            fontSize: 16,
                            color: Pallete.whiteColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.pushNamed('/login'),
                          child: const Text(
                            'Faça login',
                            style: TextStyle(
                              fontSize: 16,
                              color: Pallete.whiteColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SubmitButton(
                      label: _buttonLabel,
                      isLoading: _isLoading,
                      onPressed: _onSubmit,
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
