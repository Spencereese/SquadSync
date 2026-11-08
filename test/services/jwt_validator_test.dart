import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/jwt_validator.dart';

void main() {
  test('requireLobbyMembership fails clearly without a live client', () {
    expect(
      JwtValidator.requireLobbyMembership('lobby-1'),
      throwsA(isA<UnauthorizedException>()),
    );
  });
}
