import 'dart:convert';

import 'package:app_hiker/src/models/feed_page.dart';
import 'package:app_hiker/src/models/review.dart';
import 'package:app_hiker/src/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ReviewException implements Exception {
  final String message;
  ReviewException(this.message);

  @override
  String toString() => message;
}

class ReviewService {
  final ApiClient _apiClient;

  ReviewService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<FeedPage<Review>> getFeed({int? cursor, required int limit}) async {
    final response = await _apiClient.get('/review?limit=$limit${cursor != null ? '&cursor=$cursor' : ''}');

    if (response.statusCode == 404) return const FeedPage([], null);

    if (response.statusCode != 200) {
      throw Exception('Não foi possível carregar o feed');
    }

    return FeedPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>, Review.fromJson);
  }

  // Reviews picked for the logged user by the recommendation job, best first.
  // Empty when the job has nothing for the user yet.
  Future<List<Review>> getRecommended() async {
    final response = await _apiClient.get('/review/recommended');

    if (response.statusCode != 200) {
      throw Exception('Não foi possível carregar as recomendações');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((item) => Review.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // Reviews the logged user favorited, the last favorited first.
  Future<FeedPage<Review>> getFavorites({int? cursor, required int limit}) async {
    final response =
        await _apiClient.get('/user/me/favorites?limit=$limit${cursor != null ? '&cursor=$cursor' : ''}');

    // The API answers 404 when there is no favorite.
    if (response.statusCode == 404) return const FeedPage([], null);
    if (response.statusCode != 200) {
      throw Exception('Não foi possível carregar as favoritas');
    }

    return FeedPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>, Review.fromJson);
  }

  // 422 means it was already favorited (or already removed), so the screen is already right.
  Future<void> favoriteReview(int id) async {
    final response = await _apiClient.post('/review/favorite/$id');
    if (response.statusCode == 422) return;
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ReviewException(_extractMessage(response.body, 'Não foi possível favoritar a avaliação.'));
    }
  }

  Future<void> unfavoriteReview(int id) async {
    final response = await _apiClient.delete('/review/favorite/$id');
    if (response.statusCode == 422) return;
    if (response.statusCode != 200) {
      throw ReviewException(_extractMessage(response.body, 'Não foi possível remover dos favoritos.'));
    }
  }

  Future<List<Review>> getLocalReviews(String placeId) async {
    final response = await _apiClient.get('/review/local/${Uri.encodeComponent(placeId)}');

    if (response.statusCode == 404) return [];
    if (response.statusCode != 200) {
      throw Exception('Não foi possível carregar as avaliações do local');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((item) => Review.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // A blocked user gets a 403 with the reason in the message; the session stays.
  // 409 means the vote was already there, so the screen is already right.
  Future<void> likeReview(int id) async {
    final response = await _apiClient.post('/review/$id/like');
    if (response.statusCode == 409) return;
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ReviewException(_extractMessage(response.body, 'Não foi possível curtir a avaliação.'));
    }
  }

  Future<void> dislikeReview(int id) async {
    final response = await _apiClient.post('/review/$id/dislike');
    if (response.statusCode == 409) return;
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ReviewException(_extractMessage(response.body, 'Não foi possível descurtir a avaliação.'));
    }
  }

  Future<void> setVisibility(int id, {required bool oculto}) async {
    final response = await _apiClient.patch('/review/$id/visibility?oculto=$oculto');
    if (response.statusCode != 200) {
      throw ReviewException(_extractMessage(response.body, 'Não foi possível alterar a visibilidade.'));
    }
  }

  // categoria is the reason chosen from the list; descricao the optional details.
  Future<void> reportReview(int id, {required String categoria, String? descricao}) async {
    final response = await _apiClient.post(
      '/review/report/$id',
      body: {'categoria': categoria, 'descricao': ?descricao},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ReviewException(_extractMessage(response.body, 'Não foi possível enviar a denúncia.'));
    }
  }

  Future<void> deleteReview(int id) async {
    final response = await _apiClient.delete('/review/$id');
    if (response.statusCode != 200) {
      throw ReviewException(_extractMessage(response.body, 'Não foi possível excluir a avaliação.'));
    }
  }

  // Returns the API message, which says when the classifier hid the review as offensive.
  Future<String> createReview({
    required String localId,
    required String local,
    required String descricao,
    required int nota,
    required bool oculto,
    required List<String> tags,
    required List<String> fotoPaths,
  }) async {
    final response = await _apiClient.postMultipart(
      '/review',
      fields: {
        'local_id': localId,
        'local': local,
        'descricao': descricao,
        'nota': '$nota',
        'oculto': '$oculto',
        if (tags.isNotEmpty) 'tags': tags.join(','),
      },
      files: () => Future.wait(fotoPaths.map((path) {
        final isPng = path.toLowerCase().endsWith('.png');
        return http.MultipartFile.fromPath(
          'fotos',
          path,
          contentType: MediaType('image', isPng ? 'png' : 'jpeg'),
        );
      })),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ReviewException(_extractMessage(response.body, 'Não foi possível publicar a avaliação.'));
    }

    return _extractMessage(response.body, 'Avaliação publicada!');
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
