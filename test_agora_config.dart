import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../services/voice_service.dart';

void main() async {
  // Load environment variables
  await dotenv.load();

  debugPrint('Testing Agora Configuration...');

  // Test App ID loading
  final appIdResult = AgoraConfigEnhanced.getValidatedAppId();
  if (appIdResult.isSuccess) {
    debugPrint('✅ AGORA_APP_ID loaded successfully: ${appIdResult.data!.substring(0, 10)}...');
  } else {
    debugPrint('❌ AGORA_APP_ID failed: ${appIdResult.errorMessage}');
  }

  // Test Certificate loading
  final certResult = AgoraConfigEnhanced.getValidatedCertificate();
  if (certResult.isSuccess) {
    debugPrint('✅ AGORA_APP_CERTIFICATE loaded successfully: ${certResult.data!.substring(0, 10)}...');
  } else {
    debugPrint('❌ AGORA_APP_CERTIFICATE failed: ${certResult.errorMessage}');
  }

  debugPrint('Agora configuration test complete!');
}