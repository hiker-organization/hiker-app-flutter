import 'package:app_hiker/components/footer_menu.dart';
import 'package:app_hiker/src/pages/app/feed.dart';
import 'package:app_hiker/src/pages/app/nova_avaliacao_screen.dart';
import 'package:app_hiker/src/pages/app/perfil_screen.dart';
import 'package:app_hiker/src/pages/app/pesquisa_screen.dart';
import 'package:app_hiker/src/pages/app/trilhas_screen.dart';
import 'package:app_hiker/src/services/user_service.dart';
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _userService = UserService();

  static const _novaAvaliacaoIndex = 3;

  int _currentIndex = 0;
  int _feedVersion = 0;
  // Bumped after the profile is edited so the trails header reloads it.
  int _profileVersion = 0;
  String? _photoUrl;

  List<Widget> get _tabs => [
    FeedScreen(
      key: ValueKey(_feedVersion),
      onNovaAvaliacaoTap: () => setState(() => _currentIndex = _novaAvaliacaoIndex),
    ),
    TrilhasScreen(profileVersion: _profileVersion),
    // Rebuilt with the feed so a new review shows up on the profile.
    PerfilScreen(key: ValueKey(_feedVersion), onProfileEdited: _onProfileEdited),
    NovaAvaliacaoScreen(
      onPublished: () => setState(() {
        _feedVersion++;
        _currentIndex = 0;
      }),
    ),
    const PesquisaScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfilePhoto();
  }

  void _onProfileEdited() {
    setState(() => _profileVersion++);
    _loadProfilePhoto();
  }

  Future<void> _loadProfilePhoto() async {
    final photoUrl = await _userService.getMyPhotoUrl();
    if (mounted) setState(() => _photoUrl = photoUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: FooterMenu(
        currentIndex: _currentIndex,
        photoUrl: _photoUrl,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
