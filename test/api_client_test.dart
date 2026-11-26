import 'dart:convert';

import 'package:app_hiker/src/services/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Simulates the API: the access token 'a2' is the only valid one and each refresh token
// works once, like the real rotation.
class _FakeApi {
  var validAccessToken = 'a2';
  final validRefreshTokens = {'r1'};
  var refreshCalls = 0;
  // Runs before the refresh answers, to simulate what happens meanwhile.
  Future<void> Function()? beforeRefreshResponse;

  late final client = MockClient((request) async {
    if (request.url.path == '/auth/refresh') {
      refreshCalls++;
      final refreshToken = (jsonDecode(request.body) as Map<String, dynamic>)['refresh_token'];
      // Lets the other requests that got a 401 reach the refresh before it ends.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await beforeRefreshResponse?.call();
      if (!validRefreshTokens.remove(refreshToken)) {
        return http.Response('{"message":"Refresh token inválido."}', 401);
      }
      validRefreshTokens.add('r2');
      return http.Response(jsonEncode({'access_token': 'a2', 'refresh_token': 'r2'}), 201);
    }

    final authorized = request.headers['Authorization'] == 'Bearer $validAccessToken';
    return http.Response(authorized ? '{"ok":true}' : '{"message":"Não autorizado"}', authorized ? 200 : 401);
  });
}

void main() {
  const storage = FlutterSecureStorage();

  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=https://api.test'));

  setUp(() {
    // 'a1' expired: the next requests get a 401 and need a refresh.
    FlutterSecureStorage.setMockInitialValues({'access_token': 'a1', 'refresh_token': 'r1'});
  });

  test('requisições simultâneas com o token vencido fazem um único refresh e seguem logadas', () async {
    final api = _FakeApi();
    // Instances like the ones each service creates.
    final first = ApiClient(client: api.client, storage: storage);
    final second = ApiClient(client: api.client, storage: storage);

    final responses = await Future.wait([first.get('/feed'), second.get('/trilhas'), first.get('/recomendadas')]);

    expect(responses.map((response) => response.statusCode), everyElement(200));
    expect(api.refreshCalls, 1);
    expect(await storage.read(key: 'access_token'), 'a2');
    expect(await storage.read(key: 'refresh_token'), 'r2');
  });

  test('refresh rejeitado encerra a sessão e apaga os tokens', () async {
    final api = _FakeApi()..validRefreshTokens.clear();
    final client = ApiClient(client: api.client, storage: storage);

    await expectLater(client.get('/feed'), throwsA(isA<SessionExpiredException>()));
    expect(await storage.read(key: 'access_token'), isNull);
    expect(await storage.read(key: 'refresh_token'), isNull);
  });

  test('refresh rejeitado porque outro já trocou o token usa os tokens novos', () async {
    final api = _FakeApi()
      ..validRefreshTokens.clear()
      ..validAccessToken = 'a3';
    // Another refresh (e.g. from a request already on the way) saved new tokens meanwhile.
    api.beforeRefreshResponse = () async {
      await storage.write(key: 'access_token', value: 'a3');
      await storage.write(key: 'refresh_token', value: 'r3');
    };
    final client = ApiClient(client: api.client, storage: storage);

    final response = await client.get('/feed');

    expect(response.statusCode, 200);
    expect(await storage.read(key: 'refresh_token'), 'r3');
  });
}
