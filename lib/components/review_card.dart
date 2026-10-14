import 'package:app_hiker/components/rating_stars.dart';
import 'package:app_hiker/components/report_review_sheet.dart';
import 'package:app_hiker/components/user_avatar.dart';
import 'package:app_hiker/src/models/place_info.dart';
import 'package:app_hiker/src/models/review.dart';
import 'package:app_hiker/src/services/local_service.dart';
import 'package:app_hiker/src/services/review_service.dart';
import 'package:app_hiker/src/services/user_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ReviewCard extends StatefulWidget {
  final Review review;
  // Disabled inside a profile, where the author is the profile itself.
  final bool autorTappable;
  // Disabled on the place page itself.
  final bool localTappable;
  // Owner actions; the menu is only shown when they are provided.
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onDelete;

  const ReviewCard({
    super.key,
    required this.review,
    this.autorTappable = true,
    this.localTappable = true,
    this.onToggleVisibility,
    this.onDelete,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  final _reviewService = ReviewService();

  late bool _liked = widget.review.liked;
  late bool _disliked = widget.review.disliked;
  late int _qntLikes = widget.review.qntLikes;
  late int _qntDislikes = widget.review.qntDislikes;
  late Future<PlaceInfo?>? _place = _loadPlace();

  Future<PlaceInfo?>? _loadPlace() {
    final placeId = widget.review.idLocal;
    return placeId == null ? null : PlaceInfoCache.instance.get(placeId);
  }

  @override
  void didUpdateWidget(ReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.idLocal != widget.review.idLocal) _place = _loadPlace();
  }

  void _openLocal() {
    context.pushNamed('/local/${widget.review.idLocal}');
  }

  Future<void> _handleLike() async {
    if (_liked) return;

    final previous = (_liked, _disliked, _qntLikes, _qntDislikes);
    setState(() {
      _qntLikes++;
      if (_disliked) _qntDislikes--;
      _liked = true;
      _disliked = false;
    });

    try {
      await _reviewService.likeReview(widget.review.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = previous.$1;
          _disliked = previous.$2;
          _qntLikes = previous.$3;
          _qntDislikes = previous.$4;
        });
      }
    }
  }

  Future<void> _handleDislike() async {
    if (_disliked) return;

    final previous = (_liked, _disliked, _qntLikes, _qntDislikes);
    setState(() {
      _qntDislikes++;
      if (_liked) _qntLikes--;
      _disliked = true;
      _liked = false;
    });

    try {
      await _reviewService.dislikeReview(widget.review.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = previous.$1;
          _disliked = previous.$2;
          _qntLikes = previous.$3;
          _qntDislikes = previous.$4;
        });
      }
    }
  }

  void _openAutorProfile() {
    final nick = widget.review.autor.nomeUsuario;
    context.pushNamed('/user/${nick.replaceFirst('@', '')}');
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final hasOwnerActions = widget.onToggleVisibility != null || widget.onDelete != null;
    // Only other users' reviews; while the logged user isn't known yet, no one's.
    final myNick = UserService.myNick;
    final canReport = !hasOwnerActions && myNick != null && review.autor.nomeUsuario != myNick;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Pallete.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Pallete.whiteColor.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: widget.autorTappable ? _openAutorProfile : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      UserAvatar(photoUrl: review.autor.fotoUrl, radius: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review.autor.nomeExibicao,
                              style: const TextStyle(color: Pallete.whiteColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              RatingStars(nota: review.nota),
              if (hasOwnerActions || canReport) _buildMenu(canReport: canReport),
            ],
          ),
          const SizedBox(height: 6),
          _buildLocal(),
          if (review.oculto) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.visibility_off, size: 14, color: Pallete.whiteColor.withAlpha(160)),
                const SizedBox(width: 4),
                Text(
                  'Oculta · só você vê esta avaliação',
                  style: TextStyle(color: Pallete.whiteColor.withAlpha(160), fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(review.descricao, style: const TextStyle(color: Pallete.whiteColor)),
          const SizedBox(height: 8),
          if(review.tags.isNotEmpty) Wrap(
            spacing: 8,
            runSpacing: 4,
            children: review.tags.map((tag) => Chip(
              label: Text(tag, style: const TextStyle(color: Pallete.whiteColor)),
              backgroundColor: Pallete.primaryColor.withAlpha(99),
            )).toList(),
          ),
          if (review.fotos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.fotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    review.fotos[index],
                    width: 240,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: _handleLike,
                child: Row(
                  children: [
                    Icon(
                      Icons.thumb_up,
                      size: 16,
                      color: _liked ? Pallete.primaryColor : Pallete.whiteColor,
                    ),
                    const SizedBox(width: 4),
                    Text('$_qntLikes', style: const TextStyle(color: Pallete.whiteColor)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: _handleDislike,
                child: Row(
                  children: [
                    Icon(
                      Icons.thumb_down,
                      size: 16,
                      color: _disliked ? Pallete.primaryColor : Pallete.whiteColor,
                    ),
                    const SizedBox(width: 4),
                    Text('$_qntDislikes', style: const TextStyle(color: Pallete.whiteColor)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _report() async {
    final sent = await ReportReviewSheet.show(context, widget.review.id);
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Denúncia enviada. Obrigado por avisar!')),
      );
    }
  }

  Widget _buildMenu({required bool canReport}) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Pallete.whiteColor, size: 20),
      color: Pallete.surfaceColor,
      onSelected: (value) {
        if (value == 'visibility') widget.onToggleVisibility?.call();
        if (value == 'delete') widget.onDelete?.call();
        if (value == 'report') _report();
      },
      itemBuilder: (context) => [
        if (canReport)
          const PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: Pallete.errorColor),
                SizedBox(width: 8),
                Text('Denunciar', style: TextStyle(color: Pallete.errorColor)),
              ],
            ),
          ),
        if (widget.onToggleVisibility != null)
          PopupMenuItem(
            value: 'visibility',
            child: Text(widget.review.oculto ? 'Tornar visível' : 'Ocultar avaliação'),
          ),
        if (widget.onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Excluir', style: TextStyle(color: Pallete.errorColor)),
          ),
      ],
    );
  }

  Widget _buildLocal() {
    final review = widget.review;
    final tappable = widget.localTappable && review.idLocal != null;

    return InkWell(
      onTap: tappable ? _openLocal : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.place, size: 15, color: Pallete.primaryColor),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.local,
                    style: TextStyle(
                      color: Pallete.whiteColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: tappable ? TextDecoration.underline : null,
                      decorationColor: Pallete.whiteColor.withAlpha(90),
                    ),
                  ),
                  FutureBuilder<PlaceInfo?>(
                    future: _place,
                    initialData: review.idLocal == null ? null : PlaceInfoCache.instance.cached(review.idLocal!),
                    builder: (context, snapshot) {
                      final localidade = snapshot.data?.localidade ?? '';
                      if (localidade.isEmpty) return const SizedBox.shrink();
                      return Text(
                        localidade,
                        style: TextStyle(color: Pallete.whiteColor.withAlpha(170), fontSize: 12),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
