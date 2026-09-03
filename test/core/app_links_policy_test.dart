import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_links_policy.dart';

void main() {
  tearDown(() {
    debugSetIosSimulatorChannelValue(null);
    debugResetSimSceneHostedLog();
  });

  test('sim scene hosted line is logged once after Dart attach', () {
    const line =
        'Cod Squad: sim scene hosted FVC=true key=true inHierarchy=true size=402.0x874.0 hidden=false';
    final printed = <String>[];
    logSimSceneHostedLine(line, log: printed.add);
    logSimSceneHostedLine(line, log: printed.add);
    logSimSceneHostedLine('  $line  ', log: printed.add);
    expect(printed, [line]);
    expect(printed.single, contains('sim scene hosted FVC=true'));
  });

  test('empty hosted line is not logged', () {
    final printed = <String>[];
    logSimSceneHostedLine(null, log: printed.add);
    logSimSceneHostedLine('', log: printed.add);
    logSimSceneHostedLine('   ', log: printed.add);
    expect(printed, isEmpty);
  });

  test('sim detector does not depend on SIMULATOR_* env', () {
    expect(
      detectIosSimulator(
        channelSaysSimulator: false,
        environment: {
          'SIMULATOR_DEVICE_NAME': 'iPhone 17 Pro',
          'SIMULATOR_UDID': '748CAA89-6E32-4FDE-88A3-248F13D21235',
          'SIMULATOR_ROOT': '/',
        },
      ),
      isFalse,
    );
    expect(
      detectIosSimulator(
        channelSaysSimulator: true,
        environment: const {},
      ),
      isTrue,
    );
    expect(
      simulatorEnvKeysPresent({
        'SIMULATOR_UDID': '748CAA89-6E32-4FDE-88A3-248F13D21235',
      }),
      isTrue,
    );
    expect(simulatorEnvKeysPresent(const {}), isFalse);
  });

  test('simulator still reads getInitialLink; leftover filtered by swallow', () {
    debugSetIosSimulatorChannelValue(true);
    expect(detectIosSimulator(), isTrue);
    final plan = planAppLinkListen();
    expect(plan.consumeInitialLink, isTrue);
    expect(plan.subscribeUriLinkStream, isTrue);
    expect(
      shouldConsumeLaunchAppLink(
        isIosSimulator: true,
        url: Uri.parse(
          'codsquadapp://lobby/smoke-no-such-lobby-20260903',
        ),
      ),
      isTrue,
    );
    expect(
      shouldConsumeLaunchAppLink(
        isIosSimulator: true,
        url: Uri.parse('https://lobbiesync.app/chat/leftover'),
      ),
      isFalse,
    );
  });

  test('sim does not swallow product custom-scheme lobby URLs', () {
    expect(
      isProductCustomSchemeAppLink(
        Uri.parse('codsquadapp://lobby/smoke-no-such-lobby-20260903'),
      ),
      isTrue,
    );
    expect(
      shouldSwallowSimulatorAppLink(
        Uri.parse('codsquadapp://lobby/smoke-no-such-lobby-20260903'),
      ),
      isFalse,
    );
    expect(
      shouldSwallowSimulatorAppLink(Uri.parse('codsquadapp://chat/1')),
      isFalse,
    );
    expect(
      shouldSwallowSimulatorAppLink(
        Uri.parse('https://lobbiesync.app/chat/leftover'),
      ),
      isTrue,
    );
    expect(
      shouldSwallowSimulatorAppLink(
        Uri.parse('com.example.codsquadapp://chat/1766270568521'),
      ),
      isTrue,
    );
    expect(
      shouldSwallowSimulatorAppLink(
        Uri.parse('com.example.codsquadapp://auth-callback'),
      ),
      isFalse,
    );
    expect(
      shouldSwallowSimulatorAppLink(
        Uri.parse(
          'com.googleusercontent.apps.123:/oauth',
        ),
      ),
      isFalse,
    );
    expect(
      shouldSwallowSimulatorAppLink(
        Uri.parse('https://sfckxrnoiwetmzdycqaa.supabase.co/auth/v1/callback'),
      ),
      isFalse,
    );
  });

  test('physical device still consumes launch link and subscribes', () {
    debugSetIosSimulatorChannelValue(false);
    expect(detectIosSimulator(), isFalse);
    final plan = planAppLinkListen(isIosSimulator: false);
    expect(plan.consumeInitialLink, isTrue);
    expect(plan.subscribeUriLinkStream, isTrue);
  });
}
