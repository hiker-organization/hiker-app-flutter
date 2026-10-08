import 'dart:convert';

import 'package:app_hiker/src/models/trilha.dart';
import 'package:app_hiker/src/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class TrilhaException implements Exception {
  final String message;
  TrilhaException(this.message);

  @override
  String toString() => message;
}

class TrilhaService {
  final ApiClient _apiClient;

  TrilhaService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<List<Trilha>> getMine() => _getList('/trilha/me', 'Não foi possível carregar suas trilhas.');

  // Shared trails of every user (RF29).
  Future<List<Trilha>> getFeed() => _getList('/trilha/feed', 'Não foi possível carregar as trilhas.');

  // Shared trails of another user, for their profile.
  Future<List<Trilha>> getByUser(String nick) =>
      _getList('/trilha/user/${Uri.encodeComponent(nick)}', 'Não foi possível carregar as trilhas.');

  Future<Trilha> getById(int id) async {
    final response = await _apiClient.get('/trilha/$id');
    if (response.statusCode == 404) throw TrilhaException('Trilha não encontrada.');
    if (response.statusCode != 200) {
      throw TrilhaException(_extractMessage(response.body, 'Não foi possível carregar a trilha.'));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Trilha.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> create({
    required String nome,
    required String localId,
    required String? cidade,
    required String? estado,
    required double distanciaM,
    required int passos,
    required Duration duracao,
    required int nota,
    required String descricao,
    required TrailRoute rota,
    required bool compartilhada,
    required DateTime iniciadaEm,
    required List<String> tags,
    required List<String> fotoPaths,
  }) async {
    final response = await _apiClient.postMultipart(
      '/trilha',
      fields: {
        'nome': nome,
        'local_id': localId,
        if (cidade != null && cidade.isNotEmpty) 'cidade': cidade,
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        'distancia_m': distanciaM.toStringAsFixed(1),
        'passos': '$passos',
        'duracao_s': '${duracao.inSeconds}',
        'nota': '$nota',
        'descricao': descricao,
        'rota': jsonEncode(routeToJson(rota)),
        'compartilhada': '$compartilhada',
        'iniciada_em': iniciadaEm.toUtc().toIso8601String(),
        if (tags.isNotEmpty) 'tags': tags.join(','),
      },
      files: () => Future.wait(fotoPaths.map((path) => http.MultipartFile.fromPath(
            'fotos',
            path,
            contentType: MediaType('image', path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg'),
          ))),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw TrilhaException(_extractMessage(response.body, 'Não foi possível salvar a trilha.'));
    }
  }

  Future<void> setShared(int id, {required bool compartilhada}) async {
    final response = await _apiClient.patch('/trilha/$id/share?compartilhada=$compartilhada');
    if (response.statusCode != 200) {
      throw TrilhaException(_extractMessage(response.body, 'Não foi possível alterar o compartilhamento.'));
    }
  }

  Future<void> delete(int id) async {
    final response = await _apiClient.delete('/trilha/$id');
    if (response.statusCode != 200) {
      throw TrilhaException(_extractMessage(response.body, 'Não foi possível excluir a trilha.'));
    }
  }

  Future<List<Trilha>> _getList(String path, String errorMessage) async {
    final response = await _apiClient.get(path);
    if (response.statusCode != 200) throw TrilhaException(errorMessage);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((item) => Trilha.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  String _extractMessage(String responseBody, String fallback) {
    try {
      final message = (jsonDecode(responseBody) as Map<String, dynamic>)['message'];
      if (message is List) return message.join('\n');
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    return fallback;
  }
}
