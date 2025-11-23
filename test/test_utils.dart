import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/services/auth_service.dart';
import 'package:squad_sync/services/firestore_service.dart';
import 'package:squad_sync/services/timer_service.dart';
import 'package:squad_sync/services/media_service.dart';
import 'package:squad_sync/services/igdb_auth_service.dart';
import 'package:squad_sync/services/ai_service.dart';
import 'package:squad_sync/services/reaction_service.dart';
import 'package:squad_sync/services/grok_service.dart';
import 'package:squad_sync/services/message_service.dart';
import 'package:squad_sync/services/poll_service.dart';
import 'package:squad_sync/services/audio_service.dart';
import 'package:squad_sync/services/cache_service.dart';
import 'package:squad_sync/managers/achievement_manager.dart';
import 'package:squad_sync/managers/squad_data_manager.dart';
import 'package:squad_sync/chat/chat_service.dart';

// Generate mocks for all services and managers
@GenerateNiceMocks([
  MockSpec<AuthService>(),
  MockSpec<FirestoreService>(),
  MockSpec<TimerServiceNotifier>(),
  MockSpec<MediaService>(),
  MockSpec<IgdbAuthService>(),
  MockSpec<AiService>(),
  MockSpec<ReactionService>(),
  MockSpec<GrokService>(),
  MockSpec<MessageService>(),
  MockSpec<PollService>(),
  MockSpec<AudioService>(),
  MockSpec<CacheService>(),
  MockSpec<AchievementManager>(),
  MockSpec<SquadDataManager>(),
  MockSpec<ChatService>(),
  MockSpec<Ref>(),
])
import 'test_utils.mocks.dart';

// Provide dummy values for Mockito
void _setupDummies() {
  provideDummy<AuthService>(MockAuthService());
  provideDummy<FirestoreService>(MockFirestoreService());
  provideDummy<TimerServiceNotifier>(MockTimerServiceNotifier());
  provideDummy<MediaService>(MockMediaService());
  provideDummy<IgdbAuthService>(MockIgdbAuthService());
  provideDummy<AiService>(MockAiService());
  provideDummy<ReactionService>(MockReactionService());
  provideDummy<GrokService>(MockGrokService());
  provideDummy<MessageService>(MockMessageService());
  provideDummy<PollService>(MockPollService());
  provideDummy<AudioService>(MockAudioService());
  provideDummy<CacheService>(MockCacheService());
  provideDummy<AchievementManager>(MockAchievementManager());
  provideDummy<SquadDataManager>(MockSquadDataManager());
  provideDummy<ChatService>(MockChatService());
}

// Test environment setup/teardown utilities
void setupTestEnvironment() {
  _setupDummies();
}

void teardownTestEnvironment() {
  // Clean up any test state if needed
}
  List<Override> getServiceOverrides({
    MockAuthService? authService,
    MockFirestoreService? firestoreService,
    MockTimerService? timerService,
    MockMediaService? mediaService,
    MockIgdbAuthService? igdbAuthService,
    MockAiService? aiService,
    MockReactionService? reactionService,
    MockGrokService? grokService,
    MockMessageService? messageService,
    MockPollService? pollService,
    MockAudioService? audioService,
    MockCacheService? cacheService,
    MockAchievementManager? achievementManager,
    MockSquadDataManager? squadDataManager,
    MockChatService? chatService,
  }) {
    return [
      if (authService != null)
        authServiceProvider.overrideWithValue(authService),
      if (firestoreService != null)
        firestoreServiceProvider.overrideWithValue(firestoreService),
      if (timerService != null)
        timerServiceProvider.overrideWithValue(timerService),
      if (mediaService != null)
        mediaServiceProvider.overrideWithValue(mediaService),
      if (igdbAuthService != null)
        igdbAuthServiceProvider.overrideWithValue(igdbAuthService),
      if (aiService != null) aiServiceProvider.overrideWithValue(aiService),
      if (reactionService != null)
        reactionServiceProvider.overrideWithValue(reactionService),
      if (grokService != null)
        grokServiceProvider.overrideWithValue(grokService),
      if (messageService != null)
        messageServiceProvider.overrideWithValue(messageService),
      if (pollService != null)
        pollServiceProvider.overrideWithValue(pollService),
      if (audioService != null)
        audioServiceProvider.overrideWithValue(audioService),
      if (cacheService != null)
        cacheServiceProvider.overrideWithValue(cacheService),
      if (chatService != null)
        chatServiceProvider.overrideWithValue(chatService),
    ];
  }
}

// Helper for creating test containers with mocks
ProviderContainer createTestContainer(List<Override> overrides) {
  return ProviderContainer(
    overrides: overrides,
  );
}

// Test data helpers
class TestData {
  static const String testUserId = 'test_user_id';
  static const String testSquadId = 'test_squad_id';
  static const String testGameName = 'Warzone';

  static Map<String, dynamic> createTestUser() {
    return {
      'uid': testUserId,
      'displayName': 'Test User',
      'email': 'test@example.com',
      'photoURL': 'https://example.com/photo.jpg',
      'isBlocked': false,
      'rating': 5.0,
      'isBanned': false,
    };
  }

  static Map<String, dynamic> createTestSquad() {
    return {
      'id': testSquadId,
      'name': 'Test Squad',
      'memberUids': [testUserId],
      'gameName': testGameName,
      'maxSpots': 4,
    };
  }

  static Map<String, dynamic> createTestGame() {
    return {
      'name': testGameName,
      'maxSpots': 4,
      'imageUrl': 'https://example.com/game.jpg',
    };
  }
}
