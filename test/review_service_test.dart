import 'dart:convert';

import 'package:app_hiker/src/services/api_client.dart';
import 'package:app_hiker/src/services/review_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

// Answers every multipart request with the given response, without network or token.
class _FakeApiClient extends ApiClient {
  final http.Response response;

  _FakeApiClient(this.response);

  @override
  Future<http.Response> postMultipart(
    String path, {
    required Map<String, String> fields,
    required Future<List<http.MultipartFile>> Function() files,
  }) async =>
      response;
}

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Future<String> _create(ReviewService service) => service.createReview(
      localId: 'place-1',
      local: 'Pico do Jaraguá',
      descricao: 'Trilha linda',
      nota: 5,
      oculto: false,
      tags: const [],
      fotoPaths: const [],
    );

void main() {
  group('createReview', () {
    test('devolve o aviso quando a moderação bloqueia a review', () async {
      const aviso = 'Sua review foi criada, mas não será exibida por conter conteúdo possivelmente ofensivo.';
      final service = ReviewService(apiClient: _FakeApiClient(_json({'message': aviso, 'data': {}}, 201)));

      expect(await _create(service), aviso);
    });

    test('devolve a mensagem de sucesso da API', () async {
      final service = ReviewService(
        apiClient: _FakeApiClient(_json({'message': 'Sua review foi criada com sucesso.', 'data': {}}, 201)),
      );

      expect(await _create(service), 'Sua review foi criada com sucesso.');
    });

    test('usa a mensagem padrão quando a resposta não tem message', () async {
      final service = ReviewService(apiClient: _FakeApiClient(http.Response('', 201)));

      expect(await _create(service), 'Avaliação publicada!');
    });

    test('lança ReviewException com a mensagem da API em erro', () async {
      final service = ReviewService(
        apiClient: _FakeApiClient(_json({'message': ['descricao must be a string']}, 400)),
      );

      expect(
        _create(service),
        throwsA(isA<ReviewException>().having((e) => e.message, 'message', 'descricao must be a string')),
      );
    });
  });
}
