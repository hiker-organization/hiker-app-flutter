import 'dart:convert';

import 'package:app_hiker/src/models/user_profile.dart';
import 'package:app_hiker/src/services/api_client.dart';
import 'package:app_hiker/src/services/google_sign_in_service.dart';
import 'package:app_hiker/src/services/trail_tracker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class UserNotFoundException implements Exception {}

class UserException implements Exception {
  final String message;
  UserException(this.message);

  @override
  String toString() => message;
}

class UserService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  // Nick of the logged user, filled by getMe(). Used to tell the own profile apart
  // when opening a profile from a review.
  static String? myNick;

  UserService({ApiClient? apiClient, FlutterSecureStorage? storage})
      : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<UserProfile> getMe() async {
    final response = await _apiClient.get('/user/me');
    if (response.statusCode != 200) {
      throw Exception('Não foi possível carregar o perfil');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final profile = UserProfile.fromJson(body['data'] as Map<String, dynamic>);
    myNick = profile.nomeUsuario;
    return profile;
  }

  // Returns only the reviews that are not hidden; the API filters them out.
  Future<UserProfile> getUserProfile(String nick) async {
    final response = await _apiClient.get('/user/${Uri.encodeComponent(nick)}');
    if (response.statusCode == 404) throw UserNotFoundException();
    if (response.statusCode != 200) {
      throw Exception('Não foi possível carregar o perfil');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  // Only the provided fields are sent. nomeUsuario goes without "@"; the API adds it.
  Future<void> updateProfile({
    String? nomeUsuario,
    String? nomeExibicao,
    DateTime? dataNascimento,
    String? numeroCelular,
    String? fotoPath,
  }) async {
    final response = await _apiClient.patchMultipart(
      '/user/change-data',
      fields: {
        'nome_usuario': ?nomeUsuario,
        'nome_exibicao': ?nomeExibicao,
        'numero_celular': ?numeroCelular,
        if (dataNascimento != null) 'data_nascimento': dataNascimento.toIso8601String(),
      },
      files: () async => [
        if (fotoPath != null)
          await http.MultipartFile.fromPath(
            'foto',
            fotoPath,
            contentType: MediaType('image', fotoPath.toLowerCase().endsWith('.png') ? 'png' : 'jpeg'),
          ),
      ],
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw UserException(_extractMessage(response.body, 'Não foi possível salvar as alterações.'));
    }
  }

  // RN17.6: the API sends a code to the current e-mail; the change only applies after confirmEmailChange.
  Future<void> requestEmailChange(String email) async {
    final response = await _apiClient.post('/user/change-email', body: {'email': email});
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw UserException(_extractMessage(response.body, 'Não foi possível solicitar a alteração de e-mail.'));
    }
  }

  Future<void> confirmEmailChange(String token) async {
    final response = await _apiClient.post('/user/change-email/confirm', body: {'token': token});
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw UserException(_extractMessage(response.body, 'Código inválido ou expirado.'));
    }
  }

  Future<void> changePassword({required String senhaAtual, required String senhaNova}) async {
    final response = await _apiClient.patch(
      '/user/change-password',
      body: {'senha_atual': senhaAtual, 'senha_nova': senhaNova},
    );
    if (response.statusCode != 200) {
      throw UserException(_extractMessage(response.body, 'Não foi possível alterar a senha.'));
    }
  }

  // From then on the account also enters with this Google account, without the password.
  Future<void> linkGoogle(String idToken) async {
    final response = await _apiClient.post('/auth/google/link', body: {'id_token': idToken});
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw UserException(_extractMessage(response.body, 'Não foi possível vincular a conta Google.'));
    }
  }

  String _extractMessage(String responseBody, String fallback) {
    try {
      final message = (jsonDecode(responseBody) as Map<String, dynamic>)['message'];
      if (message is List) return message.join('\n');
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    return fallback;
  }

  Future<String?> getMyPhotoUrl() async {
    try {
      return (await getMe()).fotoUrl;
    } catch (_) {
      return null;
    }
  }

  // Validates the stored session against the API; ApiClient refreshes the token on 401.
  // Returns false only when the session is known to be invalid. Network failures and
  // server errors keep the user logged in so an offline start doesn't force a new login.
  Future<bool> hasValidSession() async {
    final accessToken = await _storage.read(key: 'access_token');
    if (accessToken == null) return false;

    try {
      final response = await _apiClient.get('/user/me').timeout(const Duration(seconds: 5));
      if (response.statusCode == 401) {
        await logout();
        return false;
      }
      return true;
    } on SessionExpiredException {
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<void> logout() async {
    await _revokeRefreshToken();
    myNick = null;
    // The trail in progress is stored on the device and belongs to this user.
    await TrailTracker.instance.discard();
    await GoogleSignInService.instance.signOut();
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  // Ends the session on the API, so the refresh token can't be used anymore. Offline or
  // with the API down the user still logs out on the device.
  Future<void> _revokeRefreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return;
    try {
      await http
          .post(
            Uri.parse('${dotenv.env['API_BASE_URL']}/auth/logout'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
