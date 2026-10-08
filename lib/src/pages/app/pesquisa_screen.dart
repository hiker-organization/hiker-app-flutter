import 'package:app_hiker/src/models/place_info.dart';
import 'package:app_hiker/src/services/api_client.dart';
import 'package:app_hiker/src/services/local_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

// Search for places already reviewed, by name or city. Runs when Enter is pressed.
class PesquisaScreen extends StatefulWidget {
  const PesquisaScreen({super.key});

  @override
  State<PesquisaScreen> createState() => _PesquisaScreenState();
}

class _PesquisaScreenState extends State<PesquisaScreen> {
  static const _minChars = 3;

  final _localService = LocalService();
  final _controller = TextEditingController();

  List<PlaceDetails>? _results;
  bool _isLoading = false;
  String? _errorMessage;
  // Only the answer of the last search is shown.
  int _searchId = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String text) async {
    final query = text.trim();
    if (query.length < _minChars) {
      setState(() {
        _results = null;
        _errorMessage = 'Digite pelo menos $_minChars letras para buscar.';
      });
      return;
    }

    final searchId = ++_searchId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await _localService.buscar(query);
      if (mounted && searchId == _searchId) setState(() => _results = results);
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } on LocalException catch (e) {
      if (mounted && searchId == _searchId) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted && searchId == _searchId) setState(() => _errorMessage = 'Não foi possível buscar os locais.');
    } finally {
      if (mounted && searchId == _searchId) setState(() => _isLoading = false);
    }
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
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Buscar local ou cidade',
                contentPadding: const EdgeInsets.all(12),
                prefixIcon: Icon(Icons.search, color: Pallete.whiteColor.withAlpha(180), size: 20),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
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
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) return _message(_errorMessage!, color: Pallete.errorColor);

    final results = _results;
    if (results == null) {
      if (_isLoading) return const SizedBox.shrink();
      return _message('Encontre locais avaliados pela comunidade.');
    }
    if (results.isEmpty) return _message('Nenhum local avaliado encontrado.');

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildResult(results[index]),
    );
  }

  Widget _buildResult(PlaceDetails place) {
    final info = place.info;
    final media = place.mediaNota;

    return Material(
      color: Pallete.surfaceColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.pushNamed('/local/${info.placeId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
        ),
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
