import 'package:app_hiker/components/user_avatar.dart';
import 'package:app_hiker/src/models/user_profile.dart';
import 'package:app_hiker/src/services/trail_tracker.dart';
import 'package:app_hiker/src/services/user_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

// Side menu opened by the feed header.
class AppDrawer extends StatefulWidget {
  // Null while the profile loads or when it failed; the header shows a placeholder.
  final UserProfile? profile;
  final VoidCallback onPerfilTap;

  const AppDrawer({super.key, required this.profile, required this.onPerfilTap});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isLoggingOut = false;

  void _openPerfil() {
    Navigator.of(context).pop();
    widget.onPerfilTap();
  }

  void _push(String route) {
    Navigator.of(context).pop();
    context.pushNamed(route);
  }

  Future<void> _logout() async {
    final hasTrail = TrailTracker.instance.hasTrail;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Pallete.surfaceColor,
        title: const Text('Sair da conta?'),
        content: Text(
          hasTrail
              ? 'A trilha em andamento será descartada.'
              : 'Você vai precisar entrar novamente para usar o app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Pallete.whiteColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair', style: TextStyle(color: Pallete.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoggingOut = true);
    await UserService().logout();
    if (mounted) context.navigate('/login');
  }

  Widget _item(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Pallete.whiteColor),
      title: Text(label, style: const TextStyle(color: Pallete.whiteColor, fontSize: 16)),
      onTap: _isLoggingOut ? null : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    return Drawer(
      backgroundColor: Pallete.backgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _isLoggingOut ? null : _openPerfil,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  children: [
                    UserAvatar(photoUrl: profile?.fotoUrl, radius: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.nomeExibicao ?? 'Meu perfil',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Pallete.whiteColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (profile != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              profile.nomeUsuario,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Pallete.whiteColor.withAlpha(160)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(color: Pallete.whiteColor.withAlpha(30), height: 1),
            const SizedBox(height: 8),
            _item(Icons.person_outline, 'Perfil', _openPerfil),
            _item(Icons.favorite_border, 'Avaliações favoritas', () => _push('/favorites')),
            _item(Icons.privacy_tip_outlined, 'Política de Privacidade', () => _push('/privacy-policy')),
            const Spacer(),
            Divider(color: Pallete.whiteColor.withAlpha(30), height: 1),
            ListTile(
              leading: _isLoggingOut
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Pallete.errorColor),
                    )
                  : const Icon(Icons.logout, color: Pallete.errorColor),
              title: const Text('Sair da conta', style: TextStyle(color: Pallete.errorColor, fontSize: 16)),
              onTap: _isLoggingOut ? null : _logout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
