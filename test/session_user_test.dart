import 'dart:convert';

import 'package:app_hiker/src/utils/session_user.dart';
import 'package:flutter_test/flutter_test.dart';

String _token(Map<String, dynamic> payload) {
  String part(Object json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(payload)}.signature';
}

void main() {
  test('reads the numeric sub as a string', () {
    expect(userIdFromToken(_token({'sub': 42, 'email': 'a@b.com', 'cargo': 'USER'})), '42');
  });

  test('handles payloads that need base64 padding', () {
    expect(userIdFromToken(_token({'sub': 7, 'email': 'ação@exemplo.com'})), '7');
  });

  test('returns null without sub', () {
    expect(userIdFromToken(_token({'email': 'a@b.com'})), isNull);
  });

  test('returns null for malformed tokens', () {
    expect(userIdFromToken('not-a-jwt'), isNull);
    expect(userIdFromToken('a.%%%.c'), isNull);
  });
}
