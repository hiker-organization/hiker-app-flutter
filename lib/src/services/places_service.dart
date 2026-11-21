import 'dart:convert';

import 'package:app_hiker/src/services/api_client.dart';
import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  final String placeId;
  final String name;
  final String? address;

  PlaceSuggestion({required this.placeId, required this.name, this.address});
}

class PlacesService {
  final ApiClient _apiClient;

  PlacesService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // With [near], the places around it come first.
  Future<List<PlaceSuggestion>> autocomplete(String input, {LatLng? near}) async {
    final location = near == null ? '' : '&lat=${near.latitude}&lng=${near.longitude}';
    final response = await _apiClient.get('/local/search?q=${Uri.encodeQueryComponent(input)}$location');

    if (response.statusCode != 200) {
      throw Exception('Não foi possível buscar locais');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((item) => item as Map<String, dynamic>)
        .map((item) => PlaceSuggestion(
              placeId: item['place_id'] as String,
              name: item['nome'] as String,
              address: item['endereco'] as String?,
            ))
        .toList();
  }
}
