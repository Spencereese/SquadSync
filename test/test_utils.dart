import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/squad_state_notifier.dart';
import 'package:squad_sync/providers/chat_state_notifier.dart';
import 'package:squad_sync/providers.dart'; // Import providers
import 'package:squad_sync/services/reaction_service.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';
import 'package:squad_sync/managers/user_manager.dart';
import 'package:squad_sync/chat/chat_service.dart';

// Generate mocks for StateNotifiers with nice defaults
@GenerateNiceMocks([
  MockSpec<SquadStateNotifier>(),
  MockSpec<ChatStateNotifier>(),
  MockSpec<ReactionService>(),
  MockSpec<SQLiteHelper>(),
  MockSpec<UserManager>(),
  MockSpec<Ref>(),
  MockSpec<ChatService>(),
])
import 'test_utils.mocks.dart';

// Provide dummy values for Mockito
void _setupDummies() {
  provideDummy<ReactionService>(MockReactionService());
  provideDummy<SQLiteHelper>(MockSQLiteHelper());
  provideDummy<UserManager>(MockUserManager());
  provideDummy<ChatService>(MockChatService());
}

// Test utilities for Riverpod overrides
class TestOverrides {
  static List<Override> getSquadStateOverrides(
      MockSquadStateNotifier mockNotifier) {
    return [
      squadStateNotifierProvider
          .overrideWith((ref) => mockNotifier as SquadStateNotifier),
    ];
  }

  static List<Override> getChatStateOverrides(
      MockChatStateNotifier mockNotifier) {
    return [
      chatStateNotifierProvider
          .overrideWith((ref) => mockNotifier as ChatStateNotifier),
    ];
  }

  static List<Override> getAllStateOverrides(
    MockSquadStateNotifier squadMock,
    MockChatStateNotifier chatMock,
  ) {
    return [
      ...getSquadStateOverrides(squadMock),
      ...getChatStateOverrides(chatMock),
    ];
  }
}

// Helper for creating test containers with mocks
ProviderContainer createTestContainer(List<Override> overrides) {
  return ProviderContainer(
    overrides: overrides,
  );
}
