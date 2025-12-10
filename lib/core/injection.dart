import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/data/datasources/user_local_datasource.dart';
import 'package:squad_sync/data/datasources/user_remote_datasource.dart';
import 'package:squad_sync/data/repositories/user_repository_impl.dart';
import 'package:squad_sync/domain/repositories/user_repository.dart';
import 'package:squad_sync/domain/usecases/get_current_user.dart';
import 'package:squad_sync/domain/usecases/update_profile_image.dart';
import 'package:squad_sync/domain/usecases/update_display_name.dart';
import 'package:squad_sync/domain/usecases/block_user.dart';
import 'package:squad_sync/domain/usecases/unblock_user.dart';
import 'package:squad_sync/domain/usecases/add_pinned_game.dart';
import 'package:squad_sync/domain/usecases/remove_pinned_game.dart';

// Game imports
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:squad_sync/data/datasources/game_local_datasource.dart';
import 'package:squad_sync/data/datasources/game_remote_datasource.dart';
import 'package:squad_sync/data/repositories/game_repository_impl.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/domain/usecases/fetch_games.dart';
import 'package:squad_sync/domain/usecases/get_game_details.dart';
import 'package:squad_sync/domain/usecases/get_popular_games.dart';
import 'package:squad_sync/domain/usecases/initialize_games.dart';
import 'package:squad_sync/domain/usecases/sync_games_to_firestore.dart';
import 'package:squad_sync/services/igdb_auth_service.dart';
import 'package:squad_sync/services/friends_service.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';

// System imports
import 'package:squad_sync/data/datasources/system_local_datasource.dart';
import 'package:squad_sync/data/datasources/system_remote_datasource.dart';
import 'package:squad_sync/data/repositories/system_repository_impl.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';
import 'package:squad_sync/domain/usecases/load_system_state.dart';
import 'package:squad_sync/domain/usecases/update_theme_mode.dart';
import 'package:squad_sync/domain/usecases/track_analytics_event.dart';
import 'package:squad_sync/domain/usecases/send_local_notification.dart';
import 'package:squad_sync/domain/usecases/update_last_sync.dart';
import 'package:squad_sync/domain/usecases/purge_old_data.dart';
import 'package:squad_sync/domain/usecases/update_notification_settings.dart';
import 'package:squad_sync/domain/usecases/check_availability.dart';
import 'package:squad_sync/domain/usecases/ban_user.dart';
import 'package:squad_sync/domain/usecases/unban_user.dart';
import 'package:squad_sync/domain/usecases/create_lobby.dart';
import 'package:squad_sync/domain/usecases/create_lobby_for_group.dart';
import 'package:squad_sync/domain/usecases/join_lobby.dart';
import 'package:squad_sync/domain/usecases/leave_lobby.dart';
import 'package:squad_sync/domain/usecases/assign_spot.dart';
import 'package:squad_sync/domain/usecases/start_spot_timer.dart';
import 'package:squad_sync/domain/usecases/process_timers.dart';
import 'package:squad_sync/domain/usecases/manage_peacock_queue.dart';
import 'package:squad_sync/domain/usecases/update_member_status.dart';
import 'package:squad_sync/domain/usecases/load_lobby_state.dart';
import 'package:squad_sync/domain/usecases/sync_lobby_data.dart';

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
import 'package:squad_sync/domain/usecases/send_message.dart';
import 'package:squad_sync/domain/usecases/load_messages.dart';
import 'package:squad_sync/domain/usecases/delta_sync.dart';
import 'package:squad_sync/domain/usecases/add_reaction.dart';
import 'package:squad_sync/domain/usecases/create_poll.dart';
import 'package:squad_sync/domain/usecases/vote_poll.dart';
import 'package:squad_sync/domain/usecases/upload_media.dart';
import 'package:squad_sync/domain/usecases/create_group.dart';
import 'package:squad_sync/domain/usecases/join_group.dart';
import 'package:squad_sync/domain/usecases/leave_group.dart';
import 'package:squad_sync/domain/usecases/update_typing_indicator.dart';
import 'package:squad_sync/domain/usecases/pin_message.dart';
import 'package:squad_sync/domain/usecases/load_media_history.dart';

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

  // Use cases
  getIt.registerSingleton<GetCurrentUser>(
    GetCurrentUser(getIt<UserRepository>()),
  );
  getIt.registerSingleton<UpdateProfileImage>(
    UpdateProfileImage(getIt<UserRepository>()),
  );
  getIt.registerSingleton<UpdateDisplayName>(
    UpdateDisplayName(getIt<UserRepository>()),
  );
  getIt.registerSingleton<BlockUser>(
    BlockUser(getIt<UserRepository>()),
  );
  getIt.registerSingleton<UnblockUser>(
    UnblockUser(getIt<UserRepository>()),
  );
  getIt.registerSingleton<AddPinnedGame>(
    AddPinnedGame(getIt<UserRepository>()),
  );
  getIt.registerSingleton<RemovePinnedGame>(
    RemovePinnedGame(getIt<UserRepository>()),
  );

  // System use cases
  getIt.registerSingleton<LoadSystemState>(
    LoadSystemState(getIt<SystemRepository>()),
  );
  getIt.registerSingleton<UpdateThemeMode>(
    UpdateThemeMode(getIt<SystemRepository>()),
  );
  getIt.registerSingleton<TrackAnalyticsEvent>(
    TrackAnalyticsEvent(getIt<SystemRepository>()),
  );
  getIt.registerSingleton<SendLocalNotification>(
    SendLocalNotification(getIt<SystemRepository>()),
  );
  getIt.registerSingleton<UpdateLastSync>(
    UpdateLastSync(getIt<SystemRepository>()),
  );
  getIt.registerSingleton<PurgeOldData>(
    PurgeOldData(getIt<SystemRepository>()),
  );
  getIt.registerSingleton<UpdateNotificationSettings>(
    UpdateNotificationSettings(getIt<SystemRepository>()),
  );
  getIt.registerSingleton<CheckAvailability>(
    CheckAvailability(getIt<SystemRepository>()),
  );
  getIt.registerSingleton<BanUser>(
    BanUser(getIt<SystemRepository>()),
  );
  getIt.registerSingleton<UnbanUser>(
    UnbanUser(getIt<SystemRepository>()),
  );

  // Squad use cases
  getIt.registerSingleton<CreateLobby>(
    CreateLobby(getIt<LobbyRepository>()),
  );
  getIt.registerSingleton<CreateLobbyForGroup>(
    CreateLobbyForGroup(getIt<LobbyRepository>()),
  );
  getIt.registerSingleton<JoinLobby>(
    JoinLobby(getIt<LobbyRepository>()),
  );
  getIt.registerSingleton<LeaveLobby>(
    LeaveLobby(getIt<LobbyRepository>()),
  );
  getIt.registerSingleton<AssignSpot>(
    AssignSpot(getIt<LobbyRepository>()),
  );
  getIt.registerSingleton<StartSpotTimer>(
    StartSpotTimer(getIt<LobbyRepository>()),
  );
  getIt.registerSingleton<ProcessTimers>(
    ProcessTimers(getIt<LobbyRepository>()),
  );
  getIt.registerSingleton<ManagePeacockQueue>(
    ManagePeacockQueue(getIt<LobbyRepository>()),
  );
  getIt.registerSingleton<UpdateMemberStatus>(
    UpdateMemberStatus(getIt<LobbyRepository>()),
  );
  getIt.registerSingleton<LoadLobbyState>(
    LoadLobbyState(getIt<LobbyRepository>()),
  );
  getIt.registerSingleton<SyncLobbyData>(
    SyncLobbyData(getIt<LobbyRepository>()),
  );

  // Chat use cases
  getIt.registerSingleton<SendMessage>(
    SendMessage(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<LoadMessages>(
    LoadMessages(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<DeltaSync>(
    DeltaSync(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<AddReaction>(
    AddReaction(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<CreatePoll>(
    CreatePoll(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<VotePoll>(
    VotePoll(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<UploadMedia>(
    UploadMedia(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<CreateGroup>(
    CreateGroup(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<JoinGroup>(
    JoinGroup(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<LeaveGroup>(
    LeaveGroup(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<UpdateTypingIndicator>(
    UpdateTypingIndicator(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<PinMessage>(
    PinMessage(getIt<ChatRepository>()),
  );
  getIt.registerSingleton<LoadMediaHistory>(
    LoadMediaHistory(getIt<ChatRepository>()),
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

  // Game use cases
  getIt.registerSingleton<FetchGames>(
    FetchGames(getIt<GameRepository>()),
  );
  getIt.registerSingleton<GetGameDetails>(
    GetGameDetails(getIt<GameRepository>()),
  );
  getIt.registerSingleton<GetPopularGames>(
    GetPopularGames(getIt<GameRepository>()),
  );
  getIt.registerSingleton<InitializeGames>(
    InitializeGames(getIt<GameRepository>()),
  );
  getIt.registerSingleton<SyncGamesToFirestore>(
    SyncGamesToFirestore(getIt<GameRepository>()),
  );

  debugPrint('Dependency injection setup completed');
}

// For Riverpod providers
final getCurrentUserProvider =
    Provider<GetCurrentUser>((ref) => getIt<GetCurrentUser>());
final updateProfileImageProvider =
    Provider<UpdateProfileImage>((ref) => getIt<UpdateProfileImage>());
final updateDisplayNameProvider =
    Provider<UpdateDisplayName>((ref) => getIt<UpdateDisplayName>());
final blockUserProvider = Provider<BlockUser>((ref) => getIt<BlockUser>());
final unblockUserProvider =
    Provider<UnblockUser>((ref) => getIt<UnblockUser>());
final addPinnedGameProvider =
    Provider<AddPinnedGame>((ref) => getIt<AddPinnedGame>());
final removePinnedGameProvider =
    Provider<RemovePinnedGame>((ref) => getIt<RemovePinnedGame>());

// Game providers
final fetchGamesProvider = Provider<FetchGames>((ref) => getIt<FetchGames>());
final getGameDetailsProvider =
    Provider<GetGameDetails>((ref) => getIt<GetGameDetails>());
final getPopularGamesProvider =
    Provider<GetPopularGames>((ref) => getIt<GetPopularGames>());
final initializeGamesProvider =
    Provider<InitializeGames>((ref) => getIt<InitializeGames>());
final syncGamesToFirestoreProvider =
    Provider<SyncGamesToFirestore>((ref) => getIt<SyncGamesToFirestore>());

// System providers
final loadSystemStateProvider =
    Provider<LoadSystemState>((ref) => getIt<LoadSystemState>());
final updateThemeModeProvider =
    Provider<UpdateThemeMode>((ref) => getIt<UpdateThemeMode>());
final trackAnalyticsEventProvider =
    Provider<TrackAnalyticsEvent>((ref) => getIt<TrackAnalyticsEvent>());
final sendLocalNotificationProvider =
    Provider<SendLocalNotification>((ref) => getIt<SendLocalNotification>());
final updateLastSyncProvider =
    Provider<UpdateLastSync>((ref) => getIt<UpdateLastSync>());
final purgeOldDataProvider =
    Provider<PurgeOldData>((ref) => getIt<PurgeOldData>());
final updateNotificationSettingsProvider = Provider<UpdateNotificationSettings>(
    (ref) => getIt<UpdateNotificationSettings>());
final checkAvailabilityProvider =
    Provider<CheckAvailability>((ref) => getIt<CheckAvailability>());
final banUserProvider = Provider<BanUser>((ref) => getIt<BanUser>());
final unbanUserProvider = Provider<UnbanUser>((ref) => getIt<UnbanUser>());

// Squad providers
final createLobbyProvider =
    Provider<CreateLobby>((ref) => getIt<CreateLobby>());
final joinLobbyProvider = Provider<JoinLobby>((ref) => getIt<JoinLobby>());
final leaveLobbyProvider = Provider<LeaveLobby>((ref) => getIt<LeaveLobby>());
final assignSpotProvider = Provider<AssignSpot>((ref) => getIt<AssignSpot>());
final startSpotTimerProvider =
    Provider<StartSpotTimer>((ref) => getIt<StartSpotTimer>());
final processTimersProvider =
    Provider<ProcessTimers>((ref) => getIt<ProcessTimers>());
final managePeacockQueueProvider =
    Provider<ManagePeacockQueue>((ref) => getIt<ManagePeacockQueue>());
final updateMemberStatusProvider =
    Provider<UpdateMemberStatus>((ref) => getIt<UpdateMemberStatus>());
final loadLobbyStateProvider =
    Provider<LoadLobbyState>((ref) => getIt<LoadLobbyState>());
final syncLobbyDataProvider =
    Provider<SyncLobbyData>((ref) => getIt<SyncLobbyData>());

// Chat providers
final sendMessageProvider =
    Provider<SendMessage>((ref) => getIt<SendMessage>());
final loadMessagesProvider =
    Provider<LoadMessages>((ref) => getIt<LoadMessages>());
final deltaSyncProvider = Provider<DeltaSync>((ref) => getIt<DeltaSync>());
final addReactionProvider =
    Provider<AddReaction>((ref) => getIt<AddReaction>());
final createPollProvider = Provider<CreatePoll>((ref) => getIt<CreatePoll>());
final votePollProvider = Provider<VotePoll>((ref) => getIt<VotePoll>());
final uploadMediaProvider =
    Provider<UploadMedia>((ref) => getIt<UploadMedia>());
final createGroupProvider =
    Provider<CreateGroup>((ref) => getIt<CreateGroup>());
final joinGroupProvider = Provider<JoinGroup>((ref) => getIt<JoinGroup>());
final leaveGroupProvider = Provider<LeaveGroup>((ref) => getIt<LeaveGroup>());
final updateTypingIndicatorProvider =
    Provider<UpdateTypingIndicator>((ref) => getIt<UpdateTypingIndicator>());
final pinMessageProvider = Provider<PinMessage>((ref) => getIt<PinMessage>());
final loadMediaHistoryProvider =
    Provider<LoadMediaHistory>((ref) => getIt<LoadMediaHistory>());

// Notifier providers
final ln.lobbyNotifierProvider =
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
