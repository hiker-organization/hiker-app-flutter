import 'dart:io';

import 'package:app_hiker/components/change_email_sheet.dart';
import 'package:app_hiker/components/change_password_sheet.dart';
import 'package:app_hiker/components/login_form.dart';
import 'package:app_hiker/components/submit_button.dart';
import 'package:app_hiker/components/user_avatar.dart';
import 'package:app_hiker/src/models/user_profile.dart';
import 'package:app_hiker/src/services/api_client.dart';
import 'package:app_hiker/src/services/user_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:image_picker/image_picker.dart';

// RF17: name, display name, phone, photo and birth date are saved together; e-mail (RN17.6)
// and password (RN17.5) have their own verified flows.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _userService = UserService();
  final _imagePicker = ImagePicker();

  final _nomeUsuarioController = TextEditingController();
  final _nomeExibicaoController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  final _celularController = TextEditingController();

  UserProfile? _profile;
  DateTime? _dataNascimento;
  XFile? _foto;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nomeUsuarioController.dispose();
    _nomeExibicaoController.dispose();
    _dataNascimentoController.dispose();
    _celularController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await _userService.getMe();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _foto = null;
        _nomeUsuarioController.text = profile.nomeUsuario.replaceFirst('@', '');
        _nomeExibicaoController.text = profile.nomeExibicao;
        _celularController.text = profile.numeroCelular ?? '';
        _setDataNascimento(profile.dataNascimento);
      });
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Não foi possível carregar seus dados.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setDataNascimento(DateTime? date) {
    _dataNascimento = date;
    _dataNascimentoController.text = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String get _celularDigits => _celularController.text.replaceAll(RegExp(r'\D'), '');

  String get _nomeUsuario => _nomeUsuarioController.text.trim().replaceFirst(RegExp(r'^@+'), '');

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  String? _validate() {
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
    if (_celularDigits.length < 10 || _celularDigits.length > 11) {
      return 'Insira um celular válido com DDD.';
    }
    if (_dataNascimento == null) return 'Informe sua data de nascimento.';
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    setState(() => _errorMessage = error);
    if (error != null) return;

    final profile = _profile!;
    final nomeUsuario = _nomeUsuario;
    final nomeExibicao = _nomeExibicaoController.text.trim();
    final nomeUsuarioChanged = '@$nomeUsuario' != profile.nomeUsuario;
    final nomeExibicaoChanged = nomeExibicao != profile.nomeExibicao;
    final dataChanged = !_sameDay(_dataNascimento, profile.dataNascimento);
    final celularChanged = _celularDigits != profile.numeroCelular;

    if (!nomeUsuarioChanged && !nomeExibicaoChanged && !dataChanged && !celularChanged && _foto == null) {
      _showMessage('Nenhuma alteração para salvar.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _userService.updateProfile(
        nomeUsuario: nomeUsuarioChanged ? nomeUsuario : null,
        nomeExibicao: nomeExibicaoChanged ? nomeExibicao : null,
        dataNascimento: dataChanged ? _dataNascimento : null,
        numeroCelular: celularChanged ? _celularDigits : null,
        fotoPath: _foto?.path,
      );
      _showMessage('Perfil atualizado.');
      await _loadProfile();
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } on UserException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Erro ao conectar com o servidor');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDataNascimento() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _setDataNascimento(picked));
  }

  Future<void> _pickFoto() async {
    final foto = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (foto != null) setState(() => _foto = foto);
  }

  Future<void> _openChangeEmail() async {
    final changed = await _showSheet(ChangeEmailSheet(currentEmail: _profile!.email ?? ''));
    if (changed == true) {
      _showMessage('E-mail alterado com sucesso.');
      await _loadProfile();
    }
  }

  Future<void> _openChangePassword() async {
    final changed = await _showSheet(const ChangePasswordSheet());
    if (changed == true) _showMessage('Senha alterada com sucesso.');
  }

  Future<bool?> _showSheet(Widget sheet) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pallete.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SingleChildScrollView(child: sheet),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _icon(IconData icon) => Icon(icon, color: Pallete.whiteColor.withAlpha(180), size: 20);

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 16),
        child: Text(text, style: TextStyle(color: Pallete.whiteColor.withAlpha(180), fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Pallete.backgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Pallete.whiteColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Editar perfil', style: TextStyle(color: Pallete.whiteColor, fontSize: 18)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final profile = _profile;
    if (profile == null) {
      if (_isLoading) return const Center(child: CircularProgressIndicator());

      // Also reached when the session expired: the screen is going to the login.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError ?? 'Não foi possível carregar o perfil.',
              style: const TextStyle(color: Pallete.errorColor),
            ),
            TextButton(
              onPressed: _loadProfile,
              child: const Text('Tentar novamente', style: TextStyle(color: Pallete.primaryColor)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFoto(profile),
              _label('Nome de usuário'),
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
              _label('Nome de exibição'),
              LoginForm(
                hintText: 'Nome de exibição',
                controller: _nomeExibicaoController,
                prefixIcon: _icon(Icons.badge_outlined),
              ),
              _label('Celular'),
              LoginForm(
                hintText: 'Celular com DDD',
                controller: _celularController,
                keyboardType: TextInputType.phone,
                prefixIcon: _icon(Icons.phone_iphone),
              ),
              _label('Data de nascimento'),
              LoginForm(
                hintText: 'Data de nascimento',
                controller: _dataNascimentoController,
                readOnly: true,
                onTap: _pickDataNascimento,
                prefixIcon: _icon(Icons.cake_outlined),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Pallete.errorColor)),
              ],
              const SizedBox(height: 24),
              SubmitButton(label: 'Salvar alterações', isLoading: _isSaving, onPressed: _save, horizontalPadding: 0),
              const SizedBox(height: 32),
              const Text('Segurança', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildSecurityTile(
                icon: Icons.mail_outline,
                title: 'E-mail',
                subtitle: profile.email ?? '',
                onTap: _isSaving ? null : _openChangeEmail,
              ),
              const SizedBox(height: 8),
              _buildSecurityTile(
                icon: Icons.lock_outline,
                title: 'Senha',
                subtitle: '••••••••',
                onTap: _isSaving ? null : _openChangePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoto(UserProfile profile) {
    return Center(
      child: GestureDetector(
        onTap: _isSaving ? null : _pickFoto,
        child: Stack(
          children: [
            UserAvatar(
              photoUrl: profile.fotoUrl,
              radius: 52,
              image: _foto != null ? FileImage(File(_foto!.path)) : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Pallete.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Pallete.backgroundColor, width: 3),
                ),
                child: const Icon(Icons.photo_camera, size: 18, color: Pallete.textDarkColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Pallete.surfaceColor,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: Pallete.primaryColor),
        title: Text(title, style: const TextStyle(color: Pallete.whiteColor)),
        subtitle: Text(subtitle, style: TextStyle(color: Pallete.whiteColor.withAlpha(160))),
        trailing: const Text('Alterar', style: TextStyle(color: Pallete.primaryColor)),
      ),
    );
  }
}
