import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_links_policy.dart';

void main() {
  test('iOS simulator does not consume leftover launch AppLinks', () {
    expect(shouldConsumeLaunchAppLink(isIosSimulator: true), isFalse);
  });

  test('physical device still consumes universal links', () {
    expect(shouldConsumeLaunchAppLink(isIosSimulator: false), isTrue);
  });
}
