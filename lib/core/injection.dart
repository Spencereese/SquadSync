import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/data/datasources/user_local_datasource.dart';
import 'package:squad_sync/data/datasources/user_remote_datasource.dart';
import 'package:squad_sync/data/repositories/user_repository_impl.dart';
import 'package:squad_sync/domain/repositories/user_repository.dart';

// Game imports
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:squad_sync/data/datasources/game_local_datasource.dart';
import 'package:squad_sync/data/datasources/game_remote_datasource.dart';
import 'package:squad_sync/data/repositories/game_repository_impl.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/services/igdb_auth_service.dart';
import 'package:squad_sync/services/friends_service.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';

// System imports
import 'package:squad_sync/data/datasources/system_local_datasource.dart';
import 'package:squad_sync/data/datasources/system_remote_datasource.dart';
import 'package:squad_sync/data/repositories/system_repository_impl.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';

// Squad imports
import 'package:squad_sync/data/datasources/lobby_local_datasource.dart';
import 'package:squad_sync/data/datasources/lobby_remote_datasource.dart';
import 'package:squad_sync/data/repositories/lobby_repository_impl.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';

// Chat imports
import 'package:squad_sync/data/datasources/chat_local_datasource.dart';
import 'package:squad_sync/data/datasources/chat_local_datasource_impl.dart';
import 'package:squad_sync/data/datasources/chat_remote_datasource.dart';
import 'package:squad_sync/data/datasources/chat_remote_datasource_impl.dart';
import 'package:squad_sync/data/repositories/chat_repository_impl.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';

import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/presentation/notifiers/user_notifier.dart';
import 'package:squad_sync/presentation/notifiers/game_notifier.dart';
import 'package:squad_sync/presentation/notifiers/system_notifier.dart';
import 'package:squad_sync/presentation/notifiers/chat_notifier.dart';

import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/domain/entities/app_user.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/domain/entities/system_state.dart';
import 'package:squad_sync/domain/entities/chat_state.dart';

final getIt = GetIt.instance;

Future<void> setupInjection() async {
  // Prevent double registration
  if (getIt.isRegistered<SharedPreferences>()) {
    debugPrint('Dependency injection already set up, skipping...');
    return;
  }

  debugPrint('Starting dependency injection setup...');
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  getIt.registerSingleton<http.Client>(http.Client());

  // Local notifications - may not work on all platforms
  try {
    getIt.registerSingleton<FlutterLocalNotificationsPlugin>(
        FlutterLocalNotificationsPlugin());
  } catch (e) {
    debugPrint('Local notifications failed to register: $e');
  }

  getIt.registerSingleton<IgdbAuthService>(IgdbAuthService());
  getIt.registerSingleton<FriendsService>(FriendsService());
  getIt.registerSingleton<SQLiteHelper>(SQLiteHelper());

  // User data sources
  getIt.registerSingleton<UserLocalDataSource>(
    UserLocalDataSourceImpl(getIt<SharedPreferences>()),
  );
  getIt.registerSingleton<UserRemoteDataSource>(
    UserRemoteDataSourceImpl(),
  );

  // System data sources
  getIt.registerSingleton<SystemLocalDataSource>(
    SystemLocalDataSourceImpl(getIt<SharedPreferences>()),
  );
  getIt.registerSingleton<SystemRemoteDataSource>(
    SystemRemoteDataSourceImpl(
      getIt<FlutterLocalNotificationsPlugin>(),
      getIt<http.Client>(),
      null, // analyticsEndpoint - can be configured later
    ),
  );

  // Squad data sources
  getIt.registerSingleton<LobbyLocalDataSource>(
    LobbyLocalDataSourceImpl(getIt<SharedPreferences>(), getIt<SQLiteHelper>()),
  );
  getIt.registerSingleton<LobbyRemoteDataSource>(
    LobbyRemoteDataSourceImpl(), // Now uses Supabase!
  );

  // Chat data sources
  getIt.registerSingleton<ChatLocalDataSource>(
    ChatLocalDataSourceImpl(getIt<SQLiteHelper>()),
  );
  getIt.registerSingleton<ChatRemoteDataSource>(
    ChatRemoteDataSourceImpl(), // Now uses Supabase!
  );

  // Repositories
  getIt.registerSingleton<UserRepository>(
    UserRepositoryImpl(
      getIt<UserLocalDataSource>(),
      getIt<UserRemoteDataSource>(),
    ),
  );

  getIt.registerSingleton<ChatRepository>(
    ChatRepositoryImpl(
      getIt<ChatLocalDataSource>(),
      getIt<ChatRemoteDataSource>(),
    ),
  );

  getIt.registerSingleton<LobbyRepository>(
    LobbyRepositoryImpl(
      getIt<LobbyLocalDataSource>(),
      getIt<LobbyRemoteDataSource>(),
    ),
  );

  getIt.registerSingleton<SystemRepository>(
    SystemRepositoryImpl(
      getIt<SystemLocalDataSource>(),
      getIt<SystemRemoteDataSource>(),
    ),
  );

  // Game services
  getIt.registerSingleton<GameLocalDataSource>(
    GameLocalDataSourceImpl(getIt<SQLiteHelper>()),
  );
  getIt.registerSingleton<GameRemoteDataSource>(
    GameRemoteDataSourceImpl(getIt<http.Client>(), getIt<IgdbAuthService>()),
  );

  // Game repository (no longer depends on Firebase)
  getIt.registerSingleton<GameRepository>(
    GameRepositoryImpl(
      getIt<GameLocalDataSource>(),
      getIt<GameRemoteDataSource>(),
    ),
  );

  debugPrint('Dependency injection setup completed');
}

// Repository providers for direct access
final userRepositoryProvider =
    Provider<UserRepository>((ref) => getIt<UserRepository>());
final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => getIt<ChatRepository>());
final lobbyRepositoryProvider =
    Provider<LobbyRepository>((ref) => getIt<LobbyRepository>());
final systemRepositoryProvider =
    Provider<SystemRepository>((ref) => getIt<SystemRepository>());
final gameRepositoryProvider =
    Provider<GameRepository>((ref) => getIt<GameRepository>());

// Notifier providers
final lobbyNotifierProvider =
    AutoDisposeAsyncNotifierProvider<LobbyNotifier, LobbyState>(
  () => LobbyNotifier(),
);

final userNotifierProvider =
    AutoDisposeAsyncNotifierProvider<UserNotifier, AppUser?>(
  () => UserNotifier(),
);

final gameNotifierProvider =
    AutoDisposeAsyncNotifierProvider<GameNotifier, GameState>(
  () => GameNotifier(),
);

final systemNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SystemNotifier, SystemState>(
  () => SystemNotifier(),
);

final chatNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ChatNotifier, ChatState>(
  () => ChatNotifier(),
);

// Other providers
final popularGamesProvider = Provider<List<Game>>((ref) {
  // This will need to be implemented properly
  return [];
});
