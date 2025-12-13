import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/chat_notifier.dart';
import 'package:squad_sync/domain/entities/chat_state.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:squad_sync/core/injection.dart';

@GenerateMocks([ChatRepository, AuthServiceSupabase])
import 'chat_notifier_test.mocks.dart';

void main() {
  late MockChatRepository mockRepository;
  late MockAuthServiceSupabase mockAuthService;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockChatRepository();
    mockAuthService = MockAuthServiceSupabase();

    // Create provider container with overrides
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ChatNotifier - Initialization', () {
    test('should initialize with initial state', () async {
      final state = await container.read(chatNotifierProvider.future);

      expect(state, isA<ChatState>());
      expect(state.selectedChatGroupId, isNull);
      expect(state.chatGroups, isEmpty);
    });

    test('should handle AsyncLoading state during initialization', () {
      final state = container.read(chatNotifierProvider);

      expect(state, isA<AsyncLoading>());
    });

    test('should initialize chat for specific group', () async {
      final chatGroupId = 'chat-group-1';

      when(mockRepository.getChatGroup(chatGroupId)).thenAnswer(
        (_) async => ChatGroup(
          id: chatGroupId,
          name: 'Test Chat',
          memberIds: ['user-1', 'user-2'],
          createdAt: DateTime.now(),
          chatType: ChatType.lobby,
        ),
      );

      when(mockRepository.getMessagesStream(chatGroupId, ChatType.lobby))
          .thenAnswer(
        (_) => Stream.value([]),
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      await notifier.initializeChat(chatGroupId, ChatType.lobby);

      final state = container.read(chatNotifierProvider).valueOrNull;
      expect(state?.selectedChatGroupId, equals(chatGroupId));
    });
  });

  group('ChatNotifier - Chat Group Selection', () {
    test('should select chat group', () async {
      final chatGroupId = 'chat-group-1';
      final testGroup = ChatGroup(
        id: chatGroupId,
        name: 'Test Chat',
        memberIds: ['user-1'],
        createdAt: DateTime.now(),
        chatType: ChatType.lobby,
      );

      when(mockRepository.getChatGroup(chatGroupId)).thenAnswer(
        (_) async => testGroup,
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      await notifier.selectChatGroup(chatGroupId);

      final state = container.read(chatNotifierProvider).valueOrNull;
      expect(state?.selectedChatGroupId, equals(chatGroupId));
      verify(mockRepository.getChatGroup(chatGroupId)).called(1);
    });

    test('should clear selected chat group', () async {
      final chatGroupId = 'chat-group-1';

      when(mockRepository.getChatGroup(chatGroupId)).thenAnswer(
        (_) async => ChatGroup(
          id: chatGroupId,
          name: 'Test Chat',
          memberIds: ['user-1'],
          createdAt: DateTime.now(),
          chatType: ChatType.lobby,
        ),
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      await notifier.selectChatGroup(chatGroupId);
      await notifier.clearSelectedChatGroup();

      final state = container.read(chatNotifierProvider).valueOrNull;
      expect(state?.selectedChatGroupId, isNull);
    });

    test('should handle error when selecting non-existent chat group',
        () async {
      when(mockRepository.getChatGroup('invalid-id')).thenThrow(
        Exception('Chat group not found'),
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      expect(
        () => notifier.selectChatGroup('invalid-id'),
        throwsException,
      );
    });
  });

  group('ChatNotifier - Chat Groups Management', () {
    test('should load chat groups', () async {
      final testGroups = [
        ChatGroup(
          id: 'group-1',
          name: 'Chat 1',
          memberIds: ['user-1'],
          createdAt: DateTime.now(),
          chatType: ChatType.lobby,
        ),
        ChatGroup(
          id: 'group-2',
          name: 'Chat 2',
          memberIds: ['user-1'],
          createdAt: DateTime.now(),
          chatType: ChatType.direct,
        ),
      ];

      when(mockRepository.getUserChatGroups('user-1')).thenAnswer(
        (_) async => testGroups,
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      await notifier.loadChatGroups('user-1');

      final state = container.read(chatNotifierProvider).valueOrNull;
      expect(state?.chatGroups.length, equals(2));
    });

    test('should create new chat group', () async {
      final newGroup = ChatGroup(
        id: 'new-group',
        name: 'New Chat',
        memberIds: ['user-1', 'user-2'],
        createdAt: DateTime.now(),
        chatType: ChatType.lobby,
      );

      when(mockRepository.createChatGroup(
        name: 'New Chat',
        memberIds: ['user-1', 'user-2'],
        chatType: ChatType.lobby,
      )).thenAnswer((_) async => newGroup);

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      await notifier.createChatGroup(
        name: 'New Chat',
        memberIds: ['user-1', 'user-2'],
        chatType: ChatType.lobby,
      );

      verify(mockRepository.createChatGroup(
        name: 'New Chat',
        memberIds: ['user-1', 'user-2'],
        chatType: ChatType.lobby,
      )).called(1);
    });
  });

  group('ChatNotifier - Online Users Tracking', () {
    test('should track online users', () async {
      final chatGroupId = 'chat-group-1';

      when(mockRepository.getChatGroup(chatGroupId)).thenAnswer(
        (_) async => ChatGroup(
          id: chatGroupId,
          name: 'Test Chat',
          memberIds: ['user-1', 'user-2'],
          createdAt: DateTime.now(),
          chatType: ChatType.lobby,
        ),
      );

      when(mockRepository.getMessagesStream(chatGroupId, ChatType.lobby))
          .thenAnswer(
        (_) => Stream.value([]),
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      await notifier.initializeChat(chatGroupId, ChatType.lobby);

      final state = container.read(chatNotifierProvider).valueOrNull;
      expect(state?.onlineUsers, isA<Map<String, Set<String>>>());
    });

    test('should update online users list', () async {
      final chatGroupId = 'chat-group-1';

      when(mockRepository.getChatGroup(chatGroupId)).thenAnswer(
        (_) async => ChatGroup(
          id: chatGroupId,
          name: 'Test Chat',
          memberIds: ['user-1', 'user-2'],
          createdAt: DateTime.now(),
          chatType: ChatType.lobby,
        ),
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      await notifier.selectChatGroup(chatGroupId);

      final state = container.read(chatNotifierProvider).valueOrNull;
      expect(state, isNotNull);
    });
  });

  group('ChatNotifier - Error Handling', () {
    test('should handle repository initialization errors', () async {
      // Repository itself should not throw during init
      final state = await container.read(chatNotifierProvider.future);
      expect(state, isA<ChatState>());
    });

    test('should handle chat group loading errors', () async {
      when(mockRepository.getUserChatGroups('user-1')).thenThrow(
        Exception('Failed to load chat groups'),
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      expect(
        () => notifier.loadChatGroups('user-1'),
        throwsException,
      );
    });

    test('should handle chat group creation errors', () async {
      when(mockRepository.createChatGroup(
        name: 'Test',
        memberIds: ['user-1'],
        chatType: ChatType.lobby,
      )).thenThrow(
        Exception('Failed to create chat group'),
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      expect(
        () => notifier.createChatGroup(
          name: 'Test',
          memberIds: ['user-1'],
          chatType: ChatType.lobby,
        ),
        throwsException,
      );
    });
  });

  group('ChatNotifier - Chat Type Handling', () {
    test('should initialize lobby chat correctly', () async {
      final chatGroupId = 'lobby-chat-1';

      when(mockRepository.getChatGroup(chatGroupId)).thenAnswer(
        (_) async => ChatGroup(
          id: chatGroupId,
          name: 'Lobby Chat',
          memberIds: ['user-1'],
          createdAt: DateTime.now(),
          chatType: ChatType.lobby,
        ),
      );

      when(mockRepository.getMessagesStream(chatGroupId, ChatType.lobby))
          .thenAnswer(
        (_) => Stream.value([]),
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      await notifier.initializeChat(chatGroupId, ChatType.lobby);

      verify(mockRepository.getMessagesStream(chatGroupId, ChatType.lobby))
          .called(1);
    });

    test('should initialize direct chat correctly', () async {
      final chatGroupId = 'direct-chat-1';

      when(mockRepository.getChatGroup(chatGroupId)).thenAnswer(
        (_) async => ChatGroup(
          id: chatGroupId,
          name: 'Direct Chat',
          memberIds: ['user-1', 'user-2'],
          createdAt: DateTime.now(),
          chatType: ChatType.direct,
        ),
      );

      when(mockRepository.getMessagesStream(chatGroupId, ChatType.direct))
          .thenAnswer(
        (_) => Stream.value([]),
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      await notifier.initializeChat(chatGroupId, ChatType.direct);

      verify(mockRepository.getMessagesStream(chatGroupId, ChatType.direct))
          .called(1);
    });

    test('should initialize group chat correctly', () async {
      final chatGroupId = 'group-chat-1';

      when(mockRepository.getChatGroup(chatGroupId)).thenAnswer(
        (_) async => ChatGroup(
          id: chatGroupId,
          name: 'Group Chat',
          memberIds: ['user-1', 'user-2', 'user-3'],
          createdAt: DateTime.now(),
          chatType: ChatType.group,
        ),
      );

      when(mockRepository.getMessagesStream(chatGroupId, ChatType.group))
          .thenAnswer(
        (_) => Stream.value([]),
      );

      await container.read(chatNotifierProvider.future);
      final notifier = container.read(chatNotifierProvider.notifier);

      await notifier.initializeChat(chatGroupId, ChatType.group);

      verify(mockRepository.getMessagesStream(chatGroupId, ChatType.group))
          .called(1);
    });
  });
}
