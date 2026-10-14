import 'package:app_hiker/components/review_card.dart';
import 'package:app_hiker/components/trail_list_tile.dart';
import 'package:app_hiker/components/user_avatar.dart';
import 'package:app_hiker/src/models/review.dart';
import 'package:app_hiker/src/models/trilha.dart';
import 'package:app_hiker/src/models/user_profile.dart';
import 'package:app_hiker/src/services/api_client.dart';
import 'package:app_hiker/src/services/review_service.dart';
import 'package:app_hiker/src/services/trilha_service.dart';
import 'package:app_hiker/src/services/user_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

// Shared body of the own profile (RF16) and of another user's profile (RF14).
// Hidden reviews are only listed on the own profile: /user/me returns them, while
// /user/:nick filters them out on the API, including from the review count.
// Trails follow the same rule: other users only see the shared ones.
class ProfileView extends StatefulWidget {
  // null opens the logged user's profile.
  final String? nick;
  // Called after returning from the edit screen, e.g. to refresh the photo in the footer.
  final VoidCallback? onProfileEdited;

  const ProfileView({super.key, this.nick, this.onProfileEdited});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _userService = UserService();
  final _reviewService = ReviewService();
  final _trilhaService = TrilhaService();

  bool _isLoading = true;
  String? _errorMessage;
  UserProfile? _profile;
  List<Review> _reviews = [];
  List<Trilha> _trilhas = [];
  String? _trilhasError;
  _ProfileTab _tab = _ProfileTab.avaliacoes;

  bool get _isOwn => widget.nick == null || widget.nick == UserService.myNick;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profileFuture = _isOwn ? _userService.getMe() : _userService.getUserProfile(widget.nick!);
      // Loaded together; Future.wait keeps an error of one from going unhandled.
      await Future.wait([profileFuture, _loadTrilhas()]);
      final profile = await profileFuture;
      if (mounted) {
        setState(() {
          _profile = profile;
          _reviews = profile.reviews;
        });
      }
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } on UserNotFoundException {
      if (mounted) setState(() => _errorMessage = 'Usuário não encontrado.');
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Não foi possível carregar o perfil.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // A failure here only affects the trails tab, the profile still opens.
  Future<void> _loadTrilhas() async {
    try {
      final trilhas = _isOwn ? await _trilhaService.getMine() : await _trilhaService.getByUser(widget.nick!);
      if (mounted) {
        setState(() {
          _trilhas = trilhas;
          _trilhasError = null;
        });
      }
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      if (mounted) setState(() => _trilhasError = 'Não foi possível carregar as trilhas.');
    }
  }

  Future<void> _openTrilha(Trilha trilha) async {
    await context.pushNamed('/trilha/${trilha.id}');
    if (mounted) await _loadTrilhas();
  }

  Future<void> _toggleVisibility(Review review) async {
    final oculto = !review.oculto;
    try {
      await _reviewService.setVisibility(review.id, oculto: oculto);
      if (!mounted) return;
      setState(() {
        _reviews = _reviews.map((r) => r.id == review.id ? _withOculto(r, oculto) : r).toList();
      });
      _showMessage(oculto ? 'Avaliação oculta. Só você pode vê-la.' : 'Avaliação visível para todos.');
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } catch (e) {
      _showMessage(e is ReviewException ? e.message : 'Não foi possível alterar a visibilidade.');
    }
  }

  Future<void> _deleteReview(Review review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Pallete.surfaceColor,
        title: const Text('Excluir avaliação'),
        content: const Text('Tem certeza que deseja excluir esta avaliação?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Pallete.whiteColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Pallete.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _reviewService.deleteReview(review.id);
      if (!mounted) return;
      setState(() => _reviews = _reviews.where((r) => r.id != review.id).toList());
      _showMessage('Avaliação excluída.');
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } catch (e) {
      _showMessage(e is ReviewException ? e.message : 'Não foi possível excluir a avaliação.');
    }
  }

  Review _withOculto(Review r, bool oculto) => Review(
        id: r.id,
        descricao: r.descricao,
        local: r.local,
        idLocal: r.idLocal,
        qntLikes: r.qntLikes,
        qntDislikes: r.qntDislikes,
        nota: r.nota,
        createdAt: r.createdAt,
        autor: r.autor,
        fotos: r.fotos,
        tags: r.tags,
        liked: r.liked,
        disliked: r.disliked,
        oculto: oculto,
      );

  Future<void> _openEditProfile() async {
    await context.pushNamed('/edit-profile');
    if (!mounted) return;
    widget.onProfileEdited?.call();
    await _loadProfile();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      if (_isLoading) return const Center(child: CircularProgressIndicator());

      // Also reached when the session expired: the screen is going to the login.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage ?? 'Não foi possível carregar o perfil.',
              style: const TextStyle(color: Pallete.errorColor),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadProfile,
              child: const Text('Tentar novamente', style: TextStyle(color: Pallete.primaryColor)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(profile),
          const SizedBox(height: 20),
          _buildTabs(),
          const SizedBox(height: 16),
          ...(_tab == _ProfileTab.avaliacoes ? _buildReviews() : _buildTrilhas()),
        ],
      ),
    );
  }

  Widget _buildHeader(UserProfile profile) {
    return Column(
      children: [
        UserAvatar(photoUrl: profile.fotoUrl, radius: 48),
        const SizedBox(height: 12),
        Text(
          profile.nomeExibicao,
          style: const TextStyle(color: Pallete.whiteColor, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(profile.nomeUsuario, style: TextStyle(color: Pallete.whiteColor.withAlpha(160))),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStat('${_reviews.length + _trilhas.length}', 'Publicações'),
            const SizedBox(width: 32),
            _buildStat(profile.reputacao.toStringAsFixed(1), 'Reputação'),
          ],
        ),
        if (_isOwn) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _openEditProfile,
            icon: const Icon(Icons.edit, size: 16, color: Pallete.primaryColor),
            label: const Text('Editar perfil', style: TextStyle(color: Pallete.primaryColor)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Pallete.primaryColor)),
          ),
        ],
      ],
    );
  }

  // Icon tabs between dividers, as in the prototype.
  Widget _buildTabs() {
    final divider = Pallete.whiteColor.withAlpha(30);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: divider), bottom: BorderSide(color: divider)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _buildTab(_ProfileTab.avaliacoes, Icons.rate_review_outlined, 'Avaliações'),
            VerticalDivider(width: 1, color: divider, indent: 10, endIndent: 10),
            _buildTab(_ProfileTab.trilhas, Icons.terrain_outlined, 'Trilhas'),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(_ProfileTab tab, IconData icon, String label) {
    final selected = _tab == tab;
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () => setState(() => _tab = tab),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: selected ? Pallete.primaryColor : Colors.transparent, width: 2),
              ),
            ),
            child: Icon(icon, color: selected ? Pallete.primaryColor : Pallete.whiteColor.withAlpha(180)),
          ),
        ),
      ),
    );
  }

  Widget _emptyMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Pallete.whiteColor.withAlpha(160))),
    );
  }

  List<Widget> _buildReviews() {
    if (_reviews.isEmpty) {
      return [
        _emptyMessage(_isOwn ? 'Você ainda não publicou nenhuma avaliação.' : 'Nenhuma avaliação por aqui ainda.'),
      ];
    }
    return [
      for (final review in _reviews) ...[
        ReviewCard(
          key: ValueKey(review.id),
          review: review,
          autorTappable: false,
          onToggleVisibility: _isOwn ? () => _toggleVisibility(review) : null,
          onDelete: _isOwn ? () => _deleteReview(review) : null,
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<Widget> _buildTrilhas() {
    if (_trilhasError != null) {
      return [
        Center(child: Text(_trilhasError!, style: const TextStyle(color: Pallete.errorColor))),
        TextButton(
          onPressed: _loadTrilhas,
          child: const Text('Tentar novamente', style: TextStyle(color: Pallete.primaryColor)),
        ),
      ];
    }
    if (_trilhas.isEmpty) {
      return [
        _emptyMessage(_isOwn ? 'Você ainda não registrou nenhuma trilha.' : 'Nenhuma trilha compartilhada ainda.'),
      ];
    }
    return [
      for (final trilha in _trilhas) ...[
        TrailListTile(key: ValueKey(trilha.id), trilha: trilha, onTap: () => _openTrilha(trilha)),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Pallete.primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Pallete.whiteColor.withAlpha(160), fontSize: 12)),
      ],
    );
  }
}

enum _ProfileTab { avaliacoes, trilhas }
