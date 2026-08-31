import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/google_auth_config.dart';

void main() {
  test('YOUR_ placeholders fail closed', () {
    dotenv.testLoad(fileInput: '''
GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
''');

    expect(GoogleAuthConfig.isPlaceholder(GoogleAuthConfig.iosClientId), isTrue);
    expect(GoogleAuthConfig.isIosClientConfigured, isFalse);
    expect(GoogleAuthConfig.canAttemptSignIn, isFalse);
  });

  test('example your_google values fail closed', () {
    dotenv.testLoad(fileInput: '''
GOOGLE_IOS_CLIENT_ID=your_google_ios_client_id.apps.googleusercontent.com
GOOGLE_WEB_CLIENT_ID=your_google_web_client_id.apps.googleusercontent.com
''');

    expect(GoogleAuthConfig.isPlaceholder(GoogleAuthConfig.iosClientId), isTrue);
    expect(GoogleAuthConfig.isPlaceholder(GoogleAuthConfig.webClientId), isTrue);
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
