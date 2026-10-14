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

  const FeedScreen({super.key, required this.onNovaAvaliacaoTap});

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
      await Future.wait([_reviews.loadNext(), _loadTrilhas(_trilhas)]);
      if (!mounted || generation != _generation) return;
      setState(() => _items = _release());
      await _fill(generation, _items.length);
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
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

  // Takes out of the buffers the items that can be shown already, newest first: the
  // ones not older than the last item loaded of each source that still has pages.
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
        if (ready) released.add(item);
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
        Header(onNovaAvaliacaoTap: widget.onNovaAvaliacaoTap),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _items.isEmpty) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Pallete.errorColor)),
      );
    }

    if (_items.isEmpty && !_hasMore) {
      return const Center(
        child: Text('Nenhuma review por aqui ainda.', style: TextStyle(color: Pallete.whiteColor)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _items.length) return _buildFooter();
          final item = _items[index];
          return item is Trilha ? TrailCard(trilha: item) : ReviewCard(review: item as Review);
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
