import 'dart:io';

import 'package:app_hiker/components/login_form.dart';
import 'package:app_hiker/components/submit_button.dart';
import 'package:app_hiker/src/services/auth_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:image_picker/image_picker.dart';

enum _Step { perfil, contato, senha, foto }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _imagePicker = ImagePicker();

  final _nomeUsuarioController = TextEditingController();
  final _nomeExibicaoController = TextEditingController();
  final _emailController = TextEditingController();
  final _celularController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  var _step = _Step.perfil;
  DateTime? _dataNascimento;
  XFile? _foto;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nomeUsuarioController.dispose();
    _nomeExibicaoController.dispose();
    _emailController.dispose();
    _celularController.dispose();
    _dataNascimentoController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  String get _nomeUsuario => _nomeUsuarioController.text.trim().replaceFirst(RegExp(r'^@+'), '');

  String get _celularDigits => _celularController.text.replaceAll(RegExp(r'\D'), '');

  String? _validateStep() {
    switch (_step) {
      case _Step.perfil:
        final nomeExibicao = _nomeExibicaoController.text.trim();
        if (_nomeUsuario.length < 3 || _nomeUsuario.length > 20) {
          return 'O nome de usuário deve ter entre 3 e 20 caracteres.';
        }
        if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(_nomeUsuario)) {
          return "O nome de usuário só pode ter letras, números, '_' ou '.'.";
        }
        if (nomeExibicao.isEmpty || nomeExibicao.length > 30) {
          return 'O nome de exibição deve ter entre 1 e 30 caracteres.';
        }
        return null;
      case _Step.contato:
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailController.text.trim())) {
          return 'Insira um email válido.';
        }
        if (_celularDigits.length < 10 || _celularDigits.length > 11) {
          return 'Insira um celular válido com DDD.';
        }
        if (_dataNascimento == null) {
          return 'Informe sua data de nascimento.';
        }
        return null;
      case _Step.senha:
        final senha = _senhaController.text;
        if (senha.length < 8 ||
            !RegExp(r'[A-Z]').hasMatch(senha) ||
            !RegExp(r'[a-z]').hasMatch(senha) ||
            !RegExp(r'\d').hasMatch(senha) ||
            !RegExp(r'[^A-Za-z0-9]').hasMatch(senha)) {
          return 'A senha precisa ter no mínimo 8 caracteres, 1 maiúscula, 1 minúscula, 1 número e 1 símbolo.';
        }
        if (senha != _confirmarSenhaController.text) {
          return 'As senhas não coincidem.';
        }
        return null;
      case _Step.foto:
        return null;
    }
  }

  void handleNext() {
    final error = _validateStep();
    setState(() {
      _errorMessage = error;
      if (error == null) _step = _Step.values[_step.index + 1];
    });
  }

  void handleBack() {
    if (_isLoading) return;
    if (_step == _Step.perfil) {
      context.pop();
      return;
    }
    setState(() {
      _step = _Step.values[_step.index - 1];
      _errorMessage = null;
    });
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

  Future<void> _pickFoto() async {
    final foto = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (foto != null) setState(() => _foto = foto);
  }

  Future<void> handleRegister({required bool withFoto}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    try {
      await _authService.register(
        nomeUsuario: _nomeUsuario,
        nomeExibicao: _nomeExibicaoController.text.trim(),
        email: email,
        senha: senha,
        numeroCelular: _celularDigits,
        dataNascimento: _dataNascimento!,
        fotoPath: withFoto ? _foto?.path : null,
      );
      await _authService.login(email: email, password: senha);
      if (mounted) context.navigate('/app');
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
      case _Step.perfil:
        return 'Crie seu perfil';
      case _Step.contato:
        return 'Como falamos com você?';
      case _Step.senha:
        return 'Proteja sua conta';
      case _Step.foto:
        return 'Adicione uma foto';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _Step.perfil:
        return 'É assim que os outros trilheiros vão te encontrar.';
      case _Step.contato:
        return 'Usamos esses dados para recuperar sua conta.';
      case _Step.senha:
        return 'Use letras maiúsculas, minúsculas, números e símbolos.';
      case _Step.foto:
        return 'Opcional. Você pode adicionar depois.';
    }
  }

  Widget _icon(IconData icon) => Icon(icon, color: Pallete.whiteColor.withAlpha(180), size: 20);

  List<Widget> get _stepFields {
    switch (_step) {
      case _Step.perfil:
        return [
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
        ];
      case _Step.contato:
        return [
          LoginForm(
            hintText: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: _icon(Icons.mail_outline),
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
        ];
      case _Step.senha:
        return [
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
        ];
      case _Step.foto:
        return [
          Center(
            child: GestureDetector(
              onTap: _isLoading ? null : _pickFoto,
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Pallete.primaryColor, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 72,
                      backgroundColor: Pallete.borderColor,
                      backgroundImage: _foto != null
                          ? FileImage(File(_foto!.path))
                          : const AssetImage('assets/img/profile.png') as ImageProvider,
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Pallete.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Pallete.backgroundColor, width: 3),
                      ),
                      child: const Icon(Icons.photo_camera, size: 20, color: Pallete.textDarkColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _foto == null ? 'Toque para escolher uma foto' : 'Toque para trocar a foto',
              style: TextStyle(color: Pallete.whiteColor.withAlpha(180)),
            ),
          ),
        ];
    }
  }

  Widget _buildHeader() {
    final total = _Step.values.length;
    final current = _step.index + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: handleBack,
              icon: const Icon(Icons.arrow_back, color: Pallete.whiteColor),
            ),
            const Spacer(),
            Image.asset('assets/img/logo.png', height: 40),
            const Spacer(),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Etapa $current de $total',
          style: const TextStyle(color: Pallete.primaryColor, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: current / total),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              color: Pallete.primaryColor,
              backgroundColor: Pallete.borderColor.withAlpha(40),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFoto = _step == _Step.foto;

    return PopScope(
      canPop: _step == _Step.perfil && !_isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) handleBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 312),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    Text(
                      _title,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitle,
                      style: TextStyle(fontSize: 15, color: Pallete.whiteColor.withAlpha(180)),
                    ),
                    const SizedBox(height: 28),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Column(
                        key: ValueKey(_step),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _stepFields,
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
                    const SizedBox(height: 32),
                    if (!isFoto)
                      SubmitButton(label: 'Continuar', onPressed: handleNext, horizontalPadding: 0)
                    else ...[
                      SubmitButton(
                        label: 'Cadastrar',
                        isLoading: _isLoading,
                        onPressed: _foto == null ? null : () => handleRegister(withFoto: true),
                        horizontalPadding: 0,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading ? null : () => handleRegister(withFoto: false),
                        child: const Text(
                          'Pular etapa',
                          style: TextStyle(color: Pallete.whiteColor, fontSize: 16),
                        ),
                      ),
                    ],
                    if (_step == _Step.perfil) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Já tem uma conta? ',
                            style: TextStyle(fontSize: 16, color: Pallete.whiteColor),
                          ),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: const Text(
                              'Faça login',
                              style: TextStyle(
                                fontSize: 16,
                                color: Pallete.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
