import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../lib/services/voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Load environment variables from the project root
    await dotenv.load(fileName: '/Users/spencereese/Documents/cod_squad_app/.env');
  });

  group('Agora Configuration Tests', () {
    test('App ID should be loaded from environment', () {
      final result = AgoraConfigEnhanced.getValidatedAppId();

      expect(result.isSuccess, true);
      expect(result.data, isNotNull);
      expect(result.data!.isNotEmpty, true);
      expect(result.data, equals('1710c9b5de4145e1bda4c63e5dc06b70'));
    });

    test('Certificate should be loaded from environment', () {
      final result = AgoraConfigEnhanced.getValidatedCertificate();

      expect(result.isSuccess, true);
      expect(result.data, isNotNull);
      expect(result.data!.isNotEmpty, true);
      expect(result.data, equals('1398dec50cc54ca5ade6aaf449324629'));
    });

    test('Should handle missing App ID gracefully in debug mode', () {
      // Temporarily clear the environment variable
      final originalValue = dotenv.env['AGORA_APP_ID'];
      dotenv.env.remove('AGORA_APP_ID');

      final result = AgoraConfigEnhanced.getValidatedAppId();

      // Restore the original value
      if (originalValue != null) {
        dotenv.env['AGORA_APP_ID'] = originalValue;
      }

      // In debug mode, it should return mock value
      expect(result.isSuccess, true);
      expect(result.data, equals('mock_app_id_for_development'));
    });
  });
}