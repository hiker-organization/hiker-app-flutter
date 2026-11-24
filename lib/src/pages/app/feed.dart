import 'package:app_hiker/components/header.dart';
import 'package:app_hiker/components/review_card.dart';
import 'package:app_hiker/components/trail_card.dart';
import 'package:app_hiker/src/models/feed_page.dart';
import 'package:app_hiker/src/models/review.dart';
import 'package:app_hiker/src/models/trilha.dart';
import 'package:app_hiker/src/services/api_client.dart';
import 'package:app_hiker/src/services/review_service.dart';
import 'package:app_hiker/src/services/trilha_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class FeedScreen extends StatefulWidget {
  final VoidCallback onNovaAvaliacaoTap;
  final VoidCallback onMenuTap;

  const FeedScreen({super.key, required this.onNovaAvaliacaoTap, required this.onMenuTap});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

// Reviews or shared trails, loaded page by page.
class _FeedSource {
  final Future<FeedPage<Object>> Function(int? cursor) fetch;
  // Loaded but not shown yet: a newer item of the other source may still be missing.
  final List<Object> buffer = [];
  int? cursor;
  bool hasMore = true;
  DateTime? oldestLoaded;

  _FeedSource(this.fetch);

  Future<void> loadNext() async {
    final page = await fetch(cursor);
    buffer.addAll(page.items);
    if (page.items.isNotEmpty) oldestLoaded = _createdAt(page.items.last);
    cursor = page.nextCursor;
    hasMore = page.nextCursor != null;
  }
}

DateTime _createdAt(Object item) => item is Review ? item.createdAt : (item as Trilha).createdAt;

class _FeedScreenState extends State<FeedScreen> {
  static const _pageSize = 10;
  // Starts loading the next page this far from the end of the list.
  static const _loadAheadPx = 600.0;

  final _reviewService = ReviewService();
  final _trilhaService = TrilhaService();
  final _scrollController = ScrollController();

  late _FeedSource _reviews;
  late _FeedSource _trilhas;

  // Shown on top under "Recomendados para você"; left out of [_items].
  List<Review> _recommended = [];
  Set<int> _recommendedIds = {};
  // Reviews and shared trails (RF29) mixed, newest first.
  List<Object> _items = [];
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
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _resetSources() {
    _reviews = _FeedSource((cursor) => _reviewService.getFeed(cursor: cursor, limit: _pageSize));
    _trilhas = _FeedSource((cursor) => _trilhaService.getFeed(cursor: cursor, limit: _pageSize));
  }

  Future<void> _loadFeed() async {
    final generation = ++_generation;
    _resetSources();
    // On a refresh the old items stay on screen until the new ones arrive.
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _loadMoreError = null;
    });

    try {
      final recommended = _loadRecommended();
      await Future.wait([_reviews.loadNext(), _loadTrilhas(_trilhas), recommended]);
      if (!mounted || generation != _generation) return;
      // The ids go in before _release, which leaves the recommended reviews out.
      final recommendedList = await recommended;
      _recommendedIds = {for (final review in recommendedList) review.id};
      setState(() {
        _recommended = recommendedList;
        _items = _release();
      });
      await _fill(generation, _items.length);
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _recommended = [];
          _recommendedIds = {};
          _items = [];
          _errorMessage = 'Não foi possível carregar o feed.';
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isLoading = false);
        _checkFilled();
      }
    }
  }

  // A failure loading trails shouldn't hide the reviews: the feed goes on without them.
  Future<void> _loadTrilhas(_FeedSource source) async {
    try {
      await source.loadNext();
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      source.hasMore = false;
    }
  }

  // A failure loading the recommendations shouldn't hide the feed: it goes on without them.
  Future<List<Review>> _loadRecommended() async {
    try {
      return await _reviewService.getRecommended();
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  // Takes out of the buffers the items that can be shown already, newest first: the
  // ones not older than the last item loaded of each source that still has pages.
  // Reviews already shown as recommended are dropped.
  List<Object> _release() {
    DateTime? limit;
    for (final source in [_reviews, _trilhas]) {
      if (!source.hasMore || source.oldestLoaded == null) continue;
      if (limit == null || source.oldestLoaded!.isAfter(limit)) limit = source.oldestLoaded;
    }

    final released = <Object>[];
    for (final source in [_reviews, _trilhas]) {
      source.buffer.removeWhere((item) {
        final ready = limit == null || !_createdAt(item).isBefore(limit);
        final recommended = item is Review && _recommendedIds.contains(item.id);
        if (ready && !recommended) released.add(item);
        return ready;
      });
    }
    return released..sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
  }

  bool get _hasMore =>
      _reviews.hasMore || _trilhas.hasMore || _reviews.buffer.isNotEmpty || _trilhas.buffer.isNotEmpty;

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
      await _fill(generation, 0);
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _loadMoreError = 'Não foi possível carregar mais itens.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isLoadingMore = false);
        _checkFilled();
      }
    }
  }

  // Loads pages until [_pageSize] new items are shown, or the feed ends.
  Future<void> _fill(int generation, int alreadyShown) async {
    var shown = alreadyShown;
    while (shown < _pageSize && (_reviews.hasMore || _trilhas.hasMore)) {
      // The source whose last loaded item is the newest is the one holding the other back.
      final next = [_reviews, _trilhas].where((s) => s.hasMore).reduce(
            (a, b) => b.oldestLoaded!.isAfter(a.oldestLoaded!) ? b : a,
          );
      if (next == _trilhas) {
        await _loadTrilhas(next);
      } else {
        await next.loadNext();
      }
      if (!mounted || generation != _generation) return;
      final released = _release();
      shown += released.length;
      setState(() => _items = [..._items, ...released]);
    }
  }

  void _retryLoadMore() {
    setState(() => _loadMoreError = null);
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Header(onNovaAvaliacaoTap: widget.onNovaAvaliacaoTap, onMenuTap: widget.onMenuTap),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    final isEmpty = _items.isEmpty && _recommended.isEmpty;

    if (_isLoading && isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && isEmpty) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Pallete.errorColor)),
      );
    }

    if (isEmpty && !_hasMore) {
      return const Center(
        child: Text('Nenhuma review por aqui ainda.', style: TextStyle(color: Pallete.whiteColor)),
      );
    }

    // The recommended reviews under their title, then the "Mais publicações" title
    // when the feed has anything after them. Nothing when there are no recommendations.
    final showFeedTitle = _recommended.isNotEmpty && (_items.isNotEmpty || _hasMore);
    final recommendedCount =
        _recommended.isEmpty ? 0 : _recommended.length + 1 + (showFeedTitle ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: recommendedCount + _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index < recommendedCount) {
            if (index == 0) return _buildSectionTitle('Recomendados para você');
            if (index > _recommended.length) return _buildSectionTitle('Mais publicações');
            return ReviewCard(review: _recommended[index - 1]);
          }
          final feedIndex = index - recommendedCount;
          if (feedIndex == _items.length) return _buildFooter();
          final item = _items[feedIndex];
          return item is Trilha ? TrailCard(trilha: item) : ReviewCard(review: item as Review);
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
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
