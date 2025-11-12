import 'package:flutter_test/flutter_test.dart';

class GamePlatformConfig {
  final bool allowCrossplay;
  final List<String> selectedConsoles;

  const GamePlatformConfig({
    required this.allowCrossplay,
    required this.selectedConsoles,
  });

  bool get isValid => selectedConsoles.isNotEmpty;
}

void main() {
  test('GamePlatformConfig can be created', () {
    final config = GamePlatformConfig(
      allowCrossplay: true,
      selectedConsoles: ['PlayStation', 'PC'],
    );
    expect(config.allowCrossplay, isTrue);
    expect(config.selectedConsoles, contains('PlayStation'));
    expect(config.selectedConsoles, contains('PC'));
    expect(config.isValid, isTrue);
  });

  test('GamePlatformConfig is invalid with no consoles', () {
    final config = GamePlatformConfig(
      allowCrossplay: true,
      selectedConsoles: [],
    );
    expect(config.isValid, isFalse);
  });

  test('GamePlatformConfig works with crossplay disabled', () {
    final config = GamePlatformConfig(
      allowCrossplay: false,
      selectedConsoles: ['Xbox', 'PC'],
    );
    expect(config.allowCrossplay, isFalse);
    expect(config.selectedConsoles, contains('Xbox'));
    expect(config.isValid, isTrue);
  });
}
