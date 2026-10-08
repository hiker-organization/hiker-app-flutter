import 'dart:async';
import 'dart:convert';

import 'package:app_hiker/src/models/place_info.dart';
import 'package:app_hiker/src/services/api_client.dart';

class LocalException implements Exception {
  final String message;
  LocalException(this.message);

  @override
  String toString() => message;
}

class LocalService {
  final ApiClient _apiClient;

  LocalService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<PlaceDetails> getDetails(String placeId) async {
    final response = await _apiClient.get('/local/${Uri.encodeComponent(placeId)}');
    if (response.statusCode == 404) throw LocalException('Local não encontrado.');
    if (response.statusCode != 200) throw LocalException('Não foi possível carregar o local.');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PlaceDetails.fromJson(body['data'] as Map<String, dynamic>);
  }

  // Search page: only places that already have reviews, with their rating.
  Future<List<PlaceDetails>> buscar(String query) async {
    final response = await _apiClient.get('/local/buscar?q=${Uri.encodeQueryComponent(query)}');
    if (response.statusCode != 200) throw LocalException('Não foi possível buscar os locais.');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((item) => PlaceDetails.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<PlaceInfo>> getMany(List<String> placeIds) async {
    final ids = placeIds.map(Uri.encodeComponent).join(',');
    final response = await _apiClient.get('/local?ids=$ids');
    if (response.statusCode != 200) throw LocalException('Não foi possível carregar os locais.');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((item) => PlaceInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

// Location of the places shown on review cards. Cards ask one by one; the requests made
// in the same moment go to the API together, and the results are kept for the session.
class PlaceInfoCache {
  PlaceInfoCache._();
  static final instance = PlaceInfoCache._();

  static const _maxPerRequest = 50;

  final _service = LocalService();
  final _cache = <String, PlaceInfo?>{};
  final _pending = <String, Completer<PlaceInfo?>>{};
  Timer? _flushTimer;

  PlaceInfo? cached(String placeId) => _cache[placeId];

  Future<PlaceInfo?> get(String placeId) {
    if (_cache.containsKey(placeId)) return Future.value(_cache[placeId]);
    final pending = _pending[placeId];
    if (pending != null) return pending.future;

    final completer = Completer<PlaceInfo?>();
    _pending[placeId] = completer;
    _flushTimer ??= Timer(const Duration(milliseconds: 50), _flush);
    return completer.future;
  }

  Future<void> _flush() async {
    _flushTimer = null;
    final batch = Map.of(_pending);
    _pending.clear();
    final ids = batch.keys.toList();

    for (var start = 0; start < ids.length; start += _maxPerRequest) {
      final chunk = ids.sublist(start, (start + _maxPerRequest).clamp(0, ids.length));
      try {
        final places = {for (final place in await _service.getMany(chunk)) place.placeId: place};
        for (final id in chunk) {
          _cache[id] = places[id];
          batch[id]!.complete(places[id]);
        }
      } catch (_) {
        // Not cached, so a later card can try again.
        for (final id in chunk) {
          batch[id]!.complete(null);
        }
      }
    }
  }
}
