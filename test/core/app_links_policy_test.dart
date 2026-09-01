import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_links_policy.dart';

void main() {
  test('iOS simulator skips initial launch link but still subscribes uriLinkStream',
      () {
    final plan = planAppLinkListen(isIosSimulator: true);
    expect(plan.consumeInitialLink, isFalse);
    expect(plan.subscribeUriLinkStream, isTrue);
    expect(shouldConsumeLaunchAppLink(isIosSimulator: true), isFalse);
    expect(shouldSubscribeUriLinkStream(), isTrue);
  });

  test('physical device still consumes launch link and subscribes', () {
    final plan = planAppLinkListen(isIosSimulator: false);
    expect(plan.consumeInitialLink, isTrue);
    expect(plan.subscribeUriLinkStream, isTrue);
    expect(shouldConsumeLaunchAppLink(isIosSimulator: false), isTrue);
  });
}
