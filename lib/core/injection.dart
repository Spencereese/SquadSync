import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/data/datasources/user_local_datasource.dart';
import 'package:squad_sync/data/datasources/user_remote_datasource.dart';
import 'package:squad_sync/data/repositories/user_repository_impl.dart';
import 'package:squad_sync/domain/repositories/user_repository.dart';

// Game imports
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:squad_sync/data/datasources/game_local_datasource.dart';
import 'package:squad_sync/data/datasources/game_remote_datasource.dart';
import 'package:squad_sync/data/repositories/game_repository_impl.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/services/igdb_auth_service.dart';
import 'package:squad_sync/services/friends_service.dart';
import 'package:squad_sync/services/error_handling_service.dart';
import 'package:squad_sync/services/constitution_manager.dart';
import 'package:squad_sync/services/supabase_service.dart';
import 'package:squad_sync/services/auto_merge_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';

// System imports
import 'package:squad_sync/data/datasources/system_local_datasource.dart';
import 'package:squad_sync/data/datasources/system_remote_datasource.dart';
import 'package:squad_sync/data/repositories/system_repository_impl.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';

// Lobby imports
import 'package:squad_sync/data/datasources/lobby_local_datasource.dart';
import 'package:squad_sync/data/datasources/lobby_remote_datasource.dart';
import 'package:squad_sync/data/repositories/lobby_repository_impl.dart';
import 'package:squad_sync/data/repositories/matchmaking_queue_repository.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';

// Chat imports
import 'package:squad_sync/data/datasources/chat_local_datasource.dart';
import 'package:squad_sync/data/datasources/chat_local_datasource_impl.dart';
import 'package:squad_sync/data/datasources/chat_remote_datasource.dart';
import 'package:squad_sync/data/datasources/chat_remote_datasource_impl.dart';
import 'package:squad_sync/data/repositories/chat_repository_impl.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';

// Note: Notifier imports removed - providers defined in notifier files (Riverpod 3.0)
import 'package:squad_sync/domain/entities/game.dart';

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

  getIt.registerSingleton<Dio>(Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  )));

  getIt.registerSingleton<http.Client>(http.Client());

  // Local notifications - may not work on all platforms
  try {
    getIt.registerSingleton<FlutterLocalNotificationsPlugin>(
        FlutterLocalNotificationsPlugin());
  } catch (e) {
    debugPrint('Local notifications failed to register: $e');
  }

  // Initialize IGDB auth service and ensure credentials are available
  final igdbAuth = IgdbAuthService();
  getIt.registerSingleton<IgdbAuthService>(igdbAuth);

  // Store credentials if not already set (from .env or hardcoded fallback)
  try {
    await igdbAuth.storeCredentials();
    debugPrint('✅ IGDB credentials initialized');
  } catch (e) {
    debugPrint('⚠️ IGDB credentials initialization failed: $e');
  }

  getIt.registerSingleton<FriendsService>(FriendsService());
  getIt.registerSingleton<ErrorHandlingService>(ErrorHandlingService());
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

  // Lobby data sources
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
    GameRemoteDataSourceImpl(getIt<Dio>(), getIt<IgdbAuthService>()),
  );

  // Game repository (no longer depends on Firebase)
  getIt.registerSingleton<GameRepository>(
    GameRepositoryImpl(
      getIt<GameLocalDataSource>(),
      getIt<GameRemoteDataSource>(),
    ),
  );

  // Auto-merge service
  getIt.registerSingleton<AutoMergeService>(AutoMergeService());

  debugPrint('Dependency injection setup completed');
}

// Repository providers for direct access
final userRepositoryProvider =
    Provider<UserRepository>((ref) => getIt<UserRepository>());
final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => getIt<ChatRepository>());
final lobbyRepositoryProvider =
    Provider<LobbyRepository>((ref) => getIt<LobbyRepository>());
final matchmakingQueueRepositoryProvider =
    Provider<MatchmakingQueueRepository>(
  (ref) => MatchmakingQueueRepositoryImpl(
    client: SupabaseService.maybeClient,
  ),
);
final systemRepositoryProvider =
    Provider<SystemRepository>((ref) => getIt<SystemRepository>());
final gameRepositoryProvider =
    Provider<GameRepository>((ref) => getIt<GameRepository>());

// Data source providers for direct access
final chatRemoteDataSourceProvider =
    Provider<ChatRemoteDataSource>((ref) => getIt<ChatRemoteDataSource>());

// Service providers
final errorHandlingServiceProvider = Provider<ErrorHandlingService>((ref) {
  if (getIt.isRegistered<ErrorHandlingService>()) {
    return getIt<ErrorHandlingService>();
  }
  // Unit tests override this; fallback avoids GetIt NotRegisteredError when
  // a harness forgets the override.
  return ErrorHandlingService();
});

/// Live Supabase client. Throws [StateError] when init was skipped —
/// never [Supabase.instance] assert in unit harnesses. Override in tests
/// that need a client; most suites override [constitutionManagerProvider]
/// instead and never read this.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final client = SupabaseService.maybeClient;
  if (client == null) {
    throw StateError(
      'Supabase client is not initialized. '
      'Call SupabaseService.initialize() or override supabaseClientProvider.',
    );
  }
  return client;
});

/// Constitution enforcement. Default injects [supabaseClientProvider].
/// Override in unit tests so harnesses never touch a live client.
final constitutionManagerProvider = Provider<ConstitutionManager>((ref) {
  return ConstitutionManager(supabase: ref.watch(supabaseClientProvider));
});

// Notifier providers are defined in their respective files (Riverpod 3.0):
// - lobbyNotifierProvider in lobby_notifier.dart
// - userNotifierProvider in user_notifier.dart
// - gameNotifierProvider in game_notifier.dart
// - systemNotifierProvider in system_notifier.dart
// - chatNotifierProvider in chat_notifier.dart
// - messageNotifierProvider in message_notifier.dart
// - mediaNotifierProvider in media_notifier.dart
// - clipNotifierProvider in clip_notifier.dart
// - gameStateNotifierProvider in game_state_notifier.dart
// - timerManagementNotifierProvider in timer_management_notifier.dart

// Other providers
final popularGamesProvider = Provider<List<Game>>((ref) {
  // This will need to be implemented properly
  return [];
});
