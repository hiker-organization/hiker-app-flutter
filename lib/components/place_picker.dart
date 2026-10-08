import 'dart:async';

import 'package:app_hiker/src/services/places_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';

// Google Places search to choose where a review or trail was. Shows the chosen place,
// with a button to choose another one.
class PlacePicker extends StatefulWidget {
  final PlaceSuggestion? selected;
  final ValueChanged<PlaceSuggestion?> onChanged;
  // Style of the screen; the search icon and the loading indicator are added here.
  final InputDecoration decoration;
  final bool enabled;

  const PlacePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.decoration,
    this.enabled = true,
  });

  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  final _placesService = PlacesService();
  final _controller = TextEditingController();

  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();

    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _error = null;
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final suggestions = await _placesService.autocomplete(query);
        if (!mounted || _controller.text.trim() != query) return;
        setState(() {
          _suggestions = suggestions;
          _error = suggestions.isEmpty ? 'Nenhum local encontrado.' : null;
        });
      } catch (_) {
        if (mounted) setState(() => _error = 'Não foi possível buscar locais.');
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _select(PlaceSuggestion place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _error = null;
      _controller.clear();
    });
    widget.onChanged(place);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    if (selected != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Pallete.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Pallete.primaryColor.withAlpha(120)),
        ),
        child: Row(
          children: [
            const Icon(Icons.place, color: Pallete.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selected.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (selected.address != null)
                    Text(
                      selected.address!,
                      style: TextStyle(fontSize: 12, color: Pallete.whiteColor.withAlpha(160)),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Trocar local',
              icon: const Icon(Icons.close, size: 20),
              onPressed: widget.enabled ? () => widget.onChanged(null) : null,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          onChanged: _onChanged,
          decoration: widget.decoration.copyWith(
            prefixIcon: Icon(Icons.search, color: Pallete.whiteColor.withAlpha(180), size: 20),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Pallete.whiteColor.withAlpha(160))),
          ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Pallete.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: _suggestions
                  .map((place) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(place.name),
                        subtitle: place.address == null ? null : Text(place.address!),
                        onTap: () => _select(place),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
