import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Id of the user (the "sub" claim) inside an access token. Only reads the payload: the
// signature is checked by the API, here the id just tells local data of each account apart.
String? userIdFromToken(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final sub = (payload as Map<String, dynamic>)['sub'];
    return sub?.toString();
  } catch (_) {
    return null;
  }
}

// Id of the logged user, from the stored access token. Null when logged out.
Future<String?> currentUserId([FlutterSecureStorage storage = const FlutterSecureStorage()]) async {
  final token = await storage.read(key: 'access_token');
  return token == null ? null : userIdFromToken(token);
}
