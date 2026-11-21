import 'dart:async';

import 'package:app_hiker/components/user_avatar.dart';
import 'package:app_hiker/src/models/place_info.dart';
import 'package:app_hiker/src/models/user_summary.dart';
import 'package:app_hiker/src/services/api_client.dart';
import 'package:app_hiker/src/services/local_service.dart';
import 'package:app_hiker/src/services/user_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

enum _Categoria { pessoas, lugares }

// Search for people and for places already reviewed. Runs while the user types and
// shows a few of each; "Ver mais" opens the full list of one of them.
class PesquisaScreen extends StatefulWidget {
  const PesquisaScreen({super.key});

  @override
  State<PesquisaScreen> createState() => _PesquisaScreenState();
}

class _PesquisaScreenState extends State<PesquisaScreen> {
  static const _debounceDelay = Duration(milliseconds: 300);
  static const _pessoasPreview = 5;
  static const _lugaresPreview = 10;
  static const _pageSize = 20;
  // Starts loading the next page this far from the end of the list.
  static const _loadAheadPx = 600.0;

  final _localService = LocalService();
  final _userService = UserService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _debounce;
  String? _query;
  bool _isLoading = false;
  // Only the answer of the last search is shown.
  int _searchId = 0;

  // Results of the search. One more than shown is asked for, to know if there are more.
  List<UserSummary>? _pessoas;
  List<PlaceDetails>? _lugares;
  String? _pessoasErro;
  String? _lugaresErro;

  // Full list of one category, opened by "Ver mais".
  _Categoria? _categoria;
  List<Object> _lista = [];
  bool _listaHasMore = false;
  bool _listaLoadingMore = false;
  String? _listaErro;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Searches a moment after the user stops typing, without a request for every letter.
  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      _search(text);
      return;
    }
    _debounce = Timer(_debounceDelay, () => _search(text));
  }

  void _onSubmitted(String text) {
    _debounce?.cancel();
    _search(text);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    _search('');
  }

  // [force] runs it again even when the text didn't change, to retry after an error.
  Future<void> _search(String text, {bool force = false}) async {
    final query = text.trim();
    if (!force && query == (_query ?? '') && _categoria == null) return;
    final searchId = ++_searchId;
    _closeCategoria();

    if (query.isEmpty) {
      setState(() {
        _query = null;
        _pessoas = null;
        _lugares = null;
        _isLoading = false;
      });
      return;
    }

    // The previous results stay on screen until the new ones arrive.
    setState(() {
      _query = query;
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _fetch(() => _userService.buscar(query, limit: _pessoasPreview + 1)),
        _fetch(() => _localService.buscar(query, limit: _lugaresPreview + 1)),
      ]);
      if (!mounted || searchId != _searchId) return;
      final (pessoas, pessoasOk) = results[0];
      final (lugares, lugaresOk) = results[1];
      setState(() {
        _pessoas = pessoas?.cast<UserSummary>() ?? [];
        _lugares = lugares?.cast<PlaceDetails>() ?? [];
        _pessoasErro = pessoasOk ? null : 'Não foi possível buscar pessoas.';
        _lugaresErro = lugaresOk ? null : 'Não foi possível buscar os locais.';
      });
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } finally {
      if (mounted && searchId == _searchId) setState(() => _isLoading = false);
    }
  }

  // A failure in one category doesn't hide the other; only an expired session goes up.
  Future<(List<Object>?, bool)> _fetch(Future<List<Object>> Function() request) async {
    try {
      return (await request(), true);
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      return (null, false);
    }
  }

  Future<List<Object>> _fetchPage(_Categoria categoria, int offset) {
    final query = _query!;
    return categoria == _Categoria.pessoas
        ? _userService.buscar(query, limit: _pageSize, offset: offset)
        : _localService.buscar(query, limit: _pageSize, offset: offset);
  }

  // Starts from what is already shown and loads the rest page by page.
  void _openCategoria(_Categoria categoria) {
    final shown = categoria == _Categoria.pessoas
        ? _pessoas!.take(_pessoasPreview).toList()
        : _lugares!.take(_lugaresPreview).toList();
    setState(() {
      _categoria = categoria;
      _lista = shown;
      _listaHasMore = true;
      _listaErro = null;
      _listaLoadingMore = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
    _loadMore();
  }

  void _closeCategoria() {
    if (_categoria == null) return;
    setState(() {
      _categoria = null;
      _lista = [];
    });
  }

  void _onScroll() {
    if (_categoria != null && _scrollController.position.extentAfter < _loadAheadPx) _loadMore();
  }

  // When the items don't fill the screen there is no scroll to ask for more.
  void _checkFilled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) _onScroll();
    });
  }

  Future<void> _loadMore() async {
    final categoria = _categoria;
    if (categoria == null || _listaLoadingMore || _listaErro != null || !_listaHasMore) return;

    final searchId = _searchId;
    setState(() => _listaLoadingMore = true);
    try {
      final page = await _fetchPage(categoria, _lista.length);
      if (!mounted || searchId != _searchId || categoria != _categoria) return;
      setState(() {
        _lista = [..._lista, ...page];
        _listaHasMore = page.length == _pageSize;
      });
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } catch (_) {
      if (mounted && searchId == _searchId && categoria == _categoria) {
        setState(() => _listaErro = categoria == _Categoria.pessoas
            ? 'Não foi possível carregar mais pessoas.'
            : 'Não foi possível carregar mais locais.');
      }
    } finally {
      if (mounted && searchId == _searchId && categoria == _categoria) {
        setState(() => _listaLoadingMore = false);
        _checkFilled();
      }
    }
  }

  void _retryLoadMore() {
    setState(() => _listaErro = null);
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _onSubmitted,
              decoration: InputDecoration(
                hintText: 'Buscar pessoas, locais ou cidades',
                contentPadding: const EdgeInsets.all(12),
                prefixIcon: Icon(Icons.search, color: Pallete.whiteColor.withAlpha(180), size: 20),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (context, value, _) => value.text.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                tooltip: 'Limpar',
                                onPressed: _clear,
                                icon: Icon(Icons.close, color: Pallete.whiteColor.withAlpha(180), size: 20),
                              ),
                      ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Pallete.borderColor, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Pallete.primaryColor),
                ),
              ),
            ),
          ),
          Expanded(child: _categoria == null ? _buildResultados() : _buildCategoria(_categoria!)),
        ],
      ),
    );
  }

  Widget _buildResultados() {
    final pessoas = _pessoas;
    final lugares = _lugares;
    if (pessoas == null || lugares == null) {
      if (_isLoading) return const SizedBox.shrink();
      return _message('Encontre pessoas e locais avaliados pela comunidade.');
    }

    final temPessoas = pessoas.isNotEmpty || _pessoasErro != null;
    final temLugares = lugares.isNotEmpty || _lugaresErro != null;
    if (!temPessoas && !temLugares) return _message('Nenhuma pessoa ou local encontrado.');

    return ListView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (temPessoas) ...[
          _sectionHeader(
            'Pessoas',
            verMais: pessoas.length > _pessoasPreview ? 'Ver mais pessoas' : null,
            onVerMais: () => _openCategoria(_Categoria.pessoas),
          ),
          if (_pessoasErro != null)
            _sectionError(_pessoasErro!)
          else
            ..._spaced(pessoas.take(_pessoasPreview).map(_buildPessoa)),
        ],
        if (temPessoas && temLugares) const SizedBox(height: 24),
        if (temLugares) ...[
          _sectionHeader(
            'Lugares',
            verMais: lugares.length > _lugaresPreview ? 'Ver mais lugares' : null,
            onVerMais: () => _openCategoria(_Categoria.lugares),
          ),
          if (_lugaresErro != null)
            _sectionError(_lugaresErro!)
          else
            ..._spaced(lugares.take(_lugaresPreview).map(_buildLugar)),
        ],
      ],
    );
  }

  Widget _buildCategoria(_Categoria categoria) {
    final isPessoas = categoria == _Categoria.pessoas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Voltar aos resultados',
                onPressed: _closeCategoria,
                icon: const Icon(Icons.arrow_back, color: Pallete.whiteColor),
              ),
              const SizedBox(width: 4),
              Text(
                isPessoas ? 'Pessoas' : 'Lugares',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _lista.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == _lista.length) return _buildFooter();
              final item = _lista[index];
              return item is UserSummary ? _buildPessoa(item) : _buildLugar(item as PlaceDetails);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_listaErro != null) {
      return Column(
        children: [
          Text(_listaErro!, style: const TextStyle(color: Pallete.errorColor)),
          TextButton(
            onPressed: _retryLoadMore,
            child: const Text('Tentar novamente', style: TextStyle(color: Pallete.primaryColor)),
          ),
        ],
      );
    }
    if (_listaLoadingMore || _listaHasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _sectionHeader(String title, {String? verMais, required VoidCallback onVerMais}) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (verMais != null)
            TextButton(
              onPressed: onVerMais,
              child: Text(verMais, style: const TextStyle(color: Pallete.primaryColor)),
            ),
        ],
      ),
    );
  }

  Widget _sectionError(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(color: Pallete.errorColor)),
        TextButton(
          onPressed: () => _search(_controller.text, force: true),
          child: const Text('Tentar novamente', style: TextStyle(color: Pallete.primaryColor)),
        ),
      ],
    );
  }

  List<Widget> _spaced(Iterable<Widget> items) => [
        for (final item in items) ...[const SizedBox(height: 12), item],
      ];

  Widget _card({required VoidCallback onTap, required Widget child}) {
    return Material(
      color: Pallete.surfaceColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }

  Widget _buildPessoa(UserSummary pessoa) {
    return _card(
      onTap: () => context.pushNamed('/user/${pessoa.nomeUsuario.replaceFirst('@', '')}'),
      child: Row(
        children: [
          UserAvatar(photoUrl: pessoa.fotoUrl, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pessoa.nomeExibicao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  pessoa.nomeUsuario,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Pallete.whiteColor.withAlpha(180)),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Pallete.whiteColor.withAlpha(160)),
        ],
      ),
    );
  }

  Widget _buildLugar(PlaceDetails place) {
    final info = place.info;
    final media = place.mediaNota;

    return _card(
      onTap: () => context.pushNamed('/local/${info.placeId}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (info.localidade.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(info.localidade, style: TextStyle(color: Pallete.whiteColor.withAlpha(180))),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Pallete.primaryColor, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      media == null ? '-' : media.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${place.totalReviews} ${place.totalReviews == 1 ? 'avaliação' : 'avaliações'}',
                      style: TextStyle(color: Pallete.whiteColor.withAlpha(160), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Pallete.whiteColor.withAlpha(160)),
        ],
      ),
    );
  }

  Widget _message(String text, {Color? color}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: color ?? Pallete.whiteColor.withAlpha(160)),
        ),
      ),
    );
  }
}
