import 'package:app_hiker/src/pages/app/profile_view.dart';
import 'package:app_hiker/src/services/trail_tracker.dart';
import 'package:app_hiker/src/services/user_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PerfilScreen extends StatefulWidget {
  final VoidCallback? onProfileEdited;

  const PerfilScreen({super.key, this.onProfileEdited});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _isLoggingOut = false;

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          ProfileView(onProfileEdited: widget.onProfileEdited),
          Positioned(
            top: 8,
            right: 8,
            // Light icon on the surface color, so it stands out from the dark background.
            child: Material(
              color: Pallete.surfaceColor,
              shape: const CircleBorder(),
              child: _isLoggingOut
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Pallete.whiteColor),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Sair da conta',
                      icon: const Icon(Icons.logout, color: Pallete.whiteColor),
                      onPressed: _logout,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
