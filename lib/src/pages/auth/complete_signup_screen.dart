import 'package:app_hiker/components/login_form.dart';
import 'package:app_hiker/components/submit_button.dart';
import 'package:app_hiker/src/services/auth_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:app_hiker/src/utils/signup_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

// First Google sign-in: the fields Google doesn't give, with the same rules as the normal
// sign-up. The email and the photo come from the Google account.
class CompleteSignupScreen extends StatefulWidget {
  final GoogleSignup signup;

  const CompleteSignupScreen({super.key, required this.signup});

  @override
  State<CompleteSignupScreen> createState() => _CompleteSignupScreenState();
}

class _CompleteSignupScreenState extends State<CompleteSignupScreen> {
  final _authService = AuthService();

  final _nomeUsuarioController = TextEditingController();
  late final _nomeExibicaoController = TextEditingController(text: _nomeExibicaoInicial());
  final _celularController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  DateTime? _dataNascimento;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nomeUsuarioController.dispose();
    _nomeExibicaoController.dispose();
    _celularController.dispose();
    _dataNascimentoController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  // The Google name, cut to the 30 characters the API accepts.
  String _nomeExibicaoInicial() {
    final nome = widget.signup.nomeExibicao?.trim() ?? '';
    return nome.length > 30 ? nome.substring(0, 30) : nome;
  }

  String? _validate() {
    if (_dataNascimento == null) return 'Informe sua data de nascimento.';
    return validateNomeUsuario(nomeUsuarioSemArroba(_nomeUsuarioController.text)) ??
        validateNomeExibicao(_nomeExibicaoController.text.trim()) ??
        validateCelular(celularDigits(_celularController.text)) ??
        validateSenha(_senhaController.text, _confirmarSenhaController.text);
  }

  Future<void> _pickDataNascimento() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;

    setState(() {
      _dataNascimento = picked;
      _dataNascimentoController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    });
  }

  Future<void> _submit() async {
    final error = _validate();
    setState(() => _errorMessage = error);
    if (error != null) return;

    setState(() => _isLoading = true);
    try {
      await _authService.registerWithGoogle(
        signupToken: widget.signup.signupToken,
        nomeUsuario: nomeUsuarioSemArroba(_nomeUsuarioController.text),
        nomeExibicao: _nomeExibicaoController.text.trim(),
        senha: _senhaController.text,
        numeroCelular: celularDigits(_celularController.text),
        dataNascimento: _dataNascimento!,
      );
      if (mounted) context.navigate('/app');
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Erro ao conectar com o servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _icon(IconData icon) => Icon(icon, color: Pallete.whiteColor.withAlpha(180), size: 20);

  @override
  Widget build(BuildContext context) {
    final fotoUrl = widget.signup.fotoUrl;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 312),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _isLoading ? null : () => context.pop(),
                        icon: const Icon(Icons.arrow_back, color: Pallete.whiteColor),
                      ),
                      const Spacer(),
                      Image.asset('assets/img/logo.png', height: 40),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Pallete.borderColor,
                      backgroundImage: fotoUrl != null
                          ? NetworkImage(fotoUrl)
                          : const AssetImage('assets/img/profile.png') as ImageProvider,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.signup.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Pallete.whiteColor.withAlpha(180)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Complete seu cadastro', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'Só falta o que o Google não informa. A senha permite entrar também sem o Google.',
                    style: TextStyle(fontSize: 15, color: Pallete.whiteColor.withAlpha(180)),
                  ),
                  const SizedBox(height: 24),
                  LoginForm(
                    hintText: 'nome_de_usuario',
                    controller: _nomeUsuarioController,
                    prefixIcon: Center(
                      widthFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 6),
                        child: Text(
                          '@',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Pallete.whiteColor.withAlpha(180),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LoginForm(
                    hintText: 'Nome de exibição',
                    controller: _nomeExibicaoController,
                    prefixIcon: _icon(Icons.badge_outlined),
                  ),
                  const SizedBox(height: 12),
                  LoginForm(
                    hintText: 'Celular com DDD',
                    controller: _celularController,
                    keyboardType: TextInputType.phone,
                    prefixIcon: _icon(Icons.phone_iphone),
                  ),
                  const SizedBox(height: 12),
                  LoginForm(
                    hintText: 'Data de nascimento',
                    controller: _dataNascimentoController,
                    readOnly: true,
                    onTap: _pickDataNascimento,
                    prefixIcon: _icon(Icons.cake_outlined),
                  ),
                  const SizedBox(height: 12),
                  LoginForm(
                    hintText: 'Senha',
                    obscureText: !_showPassword,
                    controller: _senhaController,
                    prefixIcon: _icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: _icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LoginForm(
                    hintText: 'Confirme sua senha',
                    obscureText: !_showConfirmPassword,
                    controller: _confirmarSenhaController,
                    prefixIcon: _icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: _icon(_showConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Pallete.errorColor),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SubmitButton(
                    label: 'Concluir cadastro',
                    isLoading: _isLoading,
                    onPressed: _submit,
                    horizontalPadding: 0,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
