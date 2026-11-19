import 'package:app_hiker/components/review_card.dart';
import 'package:app_hiker/src/models/review.dart';
import 'package:app_hiker/src/services/api_client.dart';
import 'package:app_hiker/src/services/review_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

// Reviews the logged user favorited, loaded page by page.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const _pageSize = 10;
  // Starts loading the next page this far from the end of the list.
  static const _loadAheadPx = 600.0;

  final _reviewService = ReviewService();
  final _scrollController = ScrollController();

  List<Review> _reviews = [];
  int? _cursor;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String? _loadMoreError;
  // A refresh makes the pages still loading from before it be ignored.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _loadMoreError = null;
    });

    try {
      final page = await _reviewService.getFavorites(limit: _pageSize);
      if (!mounted || generation != _generation) return;
      setState(() {
        _reviews = page.items;
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _reviews = [];
          _hasMore = false;
          _errorMessage = 'Não foi possível carregar as favoritas.';
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isLoading = false);
        _checkFilled();
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < _loadAheadPx) _loadMore();
  }

  // When the items don't fill the screen there is no scroll to ask for more.
  void _checkFilled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) _onScroll();
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || _loadMoreError != null || !_hasMore) return;

    final generation = _generation;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _reviewService.getFavorites(cursor: _cursor, limit: _pageSize);
      if (!mounted || generation != _generation) return;
      setState(() {
        _reviews = [..._reviews, ...page.items];
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _loadMoreError = 'Não foi possível carregar mais favoritas.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isLoadingMore = false);
        _checkFilled();
      }
    }
  }

  void _retryLoadMore() {
    setState(() => _loadMoreError = null);
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: Pallete.whiteColor),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Avaliações favoritas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _reviews.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Pallete.errorColor)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _load,
              child: const Text('Tentar novamente', style: TextStyle(color: Pallete.primaryColor)),
            ),
          ],
        ),
      );
    }

    if (_reviews.isEmpty && !_hasMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border, size: 48, color: Pallete.whiteColor.withAlpha(120)),
              const SizedBox(height: 12),
              Text(
                'Nenhuma avaliação favoritada ainda. Toque no marcador de uma avaliação para salvá-la aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Pallete.whiteColor.withAlpha(180)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _reviews.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _reviews.length) return _buildFooter();
          // A review taken out of the favorites stays until the next refresh, so it can
          // be put back, and the next page cursor never points to a deleted favorite.
          final review = _reviews[index];
          return ReviewCard(key: ValueKey(review.id), review: review);
        },
      ),
    );
  }

  Widget _buildFooter() {
    if (_loadMoreError != null) {
      return Column(
        children: [
          Text(_loadMoreError!, style: const TextStyle(color: Pallete.errorColor)),
          TextButton(
            onPressed: _retryLoadMore,
            child: const Text('Tentar novamente', style: TextStyle(color: Pallete.primaryColor)),
          ),
        ],
      );
    }
    if (_isLoadingMore || _hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox.shrink();
  }
}
