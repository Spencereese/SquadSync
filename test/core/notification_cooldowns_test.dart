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

  test('v1 last-sent stamps migrate to lastSent + duration', () {
    var now = DateTime.utc(2026, 8, 31, 12);
    final store = NotificationCooldownStore(clock: () => now);
    final lastSent = now.subtract(const Duration(minutes: 10));

    final migrated = store.loadPersisted(
      {'legacy': lastSent.toIso8601String()},
      legacyDefaultDuration: const Duration(minutes: 45),
    );

    expect(migrated, isTrue);
    expect(store.isActive('legacy'), isTrue);

    now = now.add(const Duration(minutes: 34));
    expect(store.isActive('legacy'), isTrue);
    now = now.add(const Duration(minutes: 2));
    expect(store.isActive('legacy'), isFalse);
  });

  test('v2 expiry JSON loads without treating stamps as last-sent', () {
    final now = DateTime.utc(2026, 8, 31, 12);
    final store = NotificationCooldownStore(clock: () => now);
    store.setExpiry('k', const Duration(minutes: 30));

    final copy = NotificationCooldownStore(clock: () => now);
    expect(copy.loadPersisted(store.toPersistedJson()), isFalse);
    expect(copy.isActive('k'), isTrue);
    expect(copy.toPersistedJson()['v'], 2);
  });

  test('unversioned future stamp is already expiry, not last-sent', () {
    final now = DateTime.utc(2026, 8, 31, 12);
    final store = NotificationCooldownStore(clock: () => now);
    final expiry = now.add(const Duration(minutes: 20));
    store.loadPersisted({'k': expiry.toIso8601String()});
    expect(store.isActive('k'), isTrue);
  });
}
