import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/notification_cooldowns.dart';

void main() {
  test('stores expiry so a 30m momentum window is not forced to 45m', () {
    var now = DateTime.utc(2026, 8, 31, 12);
    final store = NotificationCooldownStore(clock: () => now);

    store.setExpiry('momentum', const Duration(minutes: 30));
    store.setExpiry('default', const Duration(minutes: 45));

    expect(store.isActive('momentum'), isTrue);
    expect(store.isActive('default'), isTrue);

    now = now.add(const Duration(minutes: 31));
    expect(store.isActive('momentum'), isFalse);
    expect(store.isActive('default'), isTrue);

    now = now.add(const Duration(minutes: 15));
    expect(store.isActive('default'), isFalse);
  });

  test('unknown keys are not on cooldown', () {
    final store = NotificationCooldownStore();
    expect(store.isActive('missing'), isFalse);
  });

  test('persisted ISO map round-trips expiry instants', () {
    final now = DateTime.utc(2026, 8, 31, 12);
    final store = NotificationCooldownStore(clock: () => now);
    store.setExpiry('k', const Duration(minutes: 30));

    final copy = NotificationCooldownStore(clock: () => now);
    copy.loadIsoMap(store.toIsoMap());
    expect(copy.isActive('k'), isTrue);
    expect(copy.toIsoMap()['k'], store.toIsoMap()['k']);
  });
}
