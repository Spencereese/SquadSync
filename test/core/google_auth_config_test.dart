import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/google_auth_config.dart';

void main() {
  test('YOUR_ placeholders fail closed', () {
    expect(
      GoogleAuthConfig.isPlaceholder(
        'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com',
      ),
      isTrue,
    );
    expect(
      GoogleAuthConfig.isPlaceholder(
        'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
      ),
      isTrue,
    );
    expect(GoogleAuthConfig.notConfiguredHint, 'Google Sign-In is not configured.');
  });

  test('example your_google values fail closed', () {
    expect(
      GoogleAuthConfig.isPlaceholder(
        'your_google_ios_client_id.apps.googleusercontent.com',
      ),
      isTrue,
    );
    expect(
      GoogleAuthConfig.isPlaceholder(
        'your_google_web_client_id.apps.googleusercontent.com',
      ),
      isTrue,
    );
  });

  test('env placeholders fall back to bundled Firebase OAuth clients', () {
    dotenv.testLoad(fileInput: '''
GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
GOOGLE_WEB_CLIENT_ID=your_google_web_client_id.apps.googleusercontent.com
''');

    expect(GoogleAuthConfig.iosClientId, GoogleAuthConfig.bundledIosClientId);
    expect(GoogleAuthConfig.webClientId, GoogleAuthConfig.bundledWebClientId);
    expect(GoogleAuthConfig.isIosClientConfigured, isTrue);
    expect(GoogleAuthConfig.canAttemptSignIn, isTrue);
  });

  test('a filled client id is not a placeholder', () {
    expect(
      GoogleAuthConfig.isPlaceholder(
        '1234567890-abcdef.apps.googleusercontent.com',
      ),
      isFalse,
    );
  });
}
