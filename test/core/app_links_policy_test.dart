import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_links_policy.dart';

void main() {
  tearDown(() {
    debugSetIosSimulatorChannelValue(null);
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

  test('skip getInitialLink when channel says simulator', () {
    debugSetIosSimulatorChannelValue(true);
    expect(detectIosSimulator(), isTrue);
    final plan = planAppLinkListen();
    expect(plan.consumeInitialLink, isFalse);
    expect(plan.subscribeUriLinkStream, isTrue);
  });

  test('physical device still consumes launch link and subscribes', () {
    debugSetIosSimulatorChannelValue(false);
    expect(detectIosSimulator(), isFalse);
    final plan = planAppLinkListen(isIosSimulator: false);
    expect(plan.consumeInitialLink, isTrue);
    expect(plan.subscribeUriLinkStream, isTrue);
  });
}
