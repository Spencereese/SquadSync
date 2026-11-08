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

  test(
      'local type skips cooldown so missing ids do not collide as null_null_local',
      () {
    expect(NotificationCooldownStore.keyFor({'type': 'local'}), isNull);
    expect(NotificationCooldownStore.keyFor({}), isNull);

    final first = NotificationCooldownStore.keyFor({'type': 'local'});
    final second = NotificationCooldownStore.keyFor({'type': 'local'});
    expect(first, isNull);
    expect(second, isNull);

    var now = DateTime.utc(2026, 8, 31, 12);
    final store = NotificationCooldownStore(clock: () => now);
    // Two local shows must both be deliverable — no shared null_null_local key.
    expect(store.isActive('null_null_local'), isFalse);
    store.setExpiry('null_null_local', const Duration(minutes: 45));
    expect(
      NotificationCooldownStore.keyFor({'type': 'local'}),
      isNot('null_null_local'),
    );
  });

  test('typed payloads without ids get unique keys instead of null_null', () {
    final a = NotificationCooldownStore.keyFor(
      {'type': 'momentum'},
      uniqueSuffix: () => 'a',
    );
    final b = NotificationCooldownStore.keyFor(
      {'type': 'momentum'},
      uniqueSuffix: () => 'b',
    );
    expect(a, 'a_momentum');
    expect(b, 'b_momentum');
    expect(a, isNot(b));
    expect(a, isNot(contains('null_null')));

    expect(
      NotificationCooldownStore.keyFor({
        'type': 'peacock_assigned',
        'lobby_id': 'lobby-9',
      }),
      'none_lobby-9_peacock_assigned',
    );
  });
}
