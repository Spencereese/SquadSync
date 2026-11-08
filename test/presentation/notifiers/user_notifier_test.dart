import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/domain/entities/app_user.dart';
import 'package:squad_sync/domain/repositories/user_repository.dart';
import 'package:squad_sync/presentation/notifiers/user_notifier.dart';
import 'package:squad_sync/services/friends_service.dart';

class _Users extends Mock implements UserRepository {
  @override
  Future<AppUser?> getCurrentUser() async => null;
}

class _Friends extends Mock implements FriendsService {}

void main() {
  final getIt = GetIt.instance;

  setUp(() {
    if (getIt.isRegistered<FriendsService>()) {
      getIt.unregister<FriendsService>();
    }
    getIt.registerSingleton<FriendsService>(_Friends());
  });

  tearDown(() {
    if (getIt.isRegistered<FriendsService>()) {
      getIt.unregister<FriendsService>();
    }
  });

  test('signed-out UserNotifier settles null', () async {
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(_Users()),
      ],
    );
    addTearDown(container.dispose);

    final user = await container.read(userNotifierProvider.future);

    expect(user, isNull);
  });

  test('pinGame toggles a map entry on the signed-in user', () async {
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(_Users()),
        userNotifierProvider.overrideWith(_SeededUserNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(userNotifierProvider.notifier);
    await container.read(userNotifierProvider.future);
    await notifier.pinGame(const {'name': 'Halo'});
    expect(
      container.read(userNotifierProvider).value!.pinnedGames,
      [
        {'name': 'Halo'},
      ],
    );

    await notifier.pinGame(const {'name': 'Halo'});
    expect(
      container.read(userNotifierProvider).value!.pinnedGames,
      isEmpty,
    );
  });
}

class _SeededUserNotifier extends UserNotifier {
  @override
  Future<AppUser?> build() async {
    ref.read(userRepositoryProvider);
    return AppUser.empty().copyWith(uid: 'me', displayName: 'Me');
  }
}
