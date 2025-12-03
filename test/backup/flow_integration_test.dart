// Commented out - SquadState/currentGame deleted during squad refactor migration
/*
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:cod_squad_app/providers/user_notifier.dart';
import 'package:cod_squad_app/providers/squad_notifier.dart';
import 'package:cod_squad_app/providers/chat_notifier.dart';
import 'package:cod_squad_app/chat/message.dart';

void main() {
  group('Flow Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('squad join flow integration', (WidgetTester tester) async {
      // Test the complete flow of joining a squad
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                // Simulate squad join flow
                final userState = UserState.initial().copyWith(
                  displayName: 'TestUser',
                  isInitialized: true,
                );

                final squadState = SquadState.initial().copyWith(
                  selectedSquadId: 'test-squad',
                  currentSquadData: {'name': 'Test Squad'},
                  squadMemberUids: ['user-uid'],
                  isInitialized: true,
                  isInitialDataLoaded: true,
                );

                final chatState = ChatState.initial().copyWith(
                  isInitialized: true,
                );

                expect(userState.displayName, 'TestUser');
                expect(squadState.selectedSquadId, 'test-squad');
                expect(chatState.isInitialized, isTrue);

                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('voice room flow integration', (WidgetTester tester) async {
      // Test voice room state management flow
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final squadState = SquadState.initial().copyWith(
                  currentGame: {'name': 'VoiceGame', 'voiceEnabled': true},
                  gameStatuses: {
                    'VoiceGame': {'user1': 'InVoice', 'user2': 'InVoice'},
                  },
                );

                final chatState = ChatState.initial().copyWith(
                  isRecording: true,
                  typingUsers: ['user1'],
                );

                expect(squadState.currentGame?['voiceEnabled'], isTrue);
                expect(chatState.isRecording, isTrue);
                expect(chatState.typingUsers, contains('user1'));

                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    test('state transitions maintain data integrity', () {
      // Test that state transitions don't lose data
      final initialUserState = UserState.initial();
      final updatedUserState = initialUserState.copyWith(
        displayName: 'UpdatedUser',
        blockedUsers: ['blocked-user'],
      );

      final initialSquadState = SquadState.initial();
      final updatedSquadState = initialSquadState.copyWith(
        selectedSquadId: 'squad-123',
        gameSquadSpots: {
          'Game1': ['user1', 'user2']
        },
      );

      final initialChatState = ChatState.initial();
      final updatedChatState = initialChatState.copyWith(
        messages: [
          Message(
            sender: 'user1',
            content: 'Hello',
            timestamp: DateTime.now(),
            reactions: [],
          ),
        ],
        unreadCount: 1,
      );

      // Verify data integrity
      expect(updatedUserState.displayName, 'UpdatedUser');
      expect(updatedUserState.blockedUsers, hasLength(1));

      expect(updatedSquadState.selectedSquadId, 'squad-123');
      expect(updatedSquadState.gameSquadSpots['Game1'], hasLength(2));

      expect(updatedChatState.messages, hasLength(1));
      expect(updatedChatState.unreadCount, 1);
    });

    test('error recovery maintains state', () {
      // Test error recovery
      final errorUserState =
          AsyncValue.error('Network error', StackTrace.current);
      final recoveredUserState = UserState.initial().copyWith(
        displayName: 'RecoveredUser',
        isInitialized: true,
      );

      expect(errorUserState.hasError, isTrue);
      expect(recoveredUserState.displayName, 'RecoveredUser');
      expect(recoveredUserState.isInitialized, isTrue);
    });

    test('offline to online transition', () {
      // Test offline to online data sync
      final offlineState = SquadState.initial().copyWith(
        gameSquadSpots: {
          'Game1': ['user1']
        },
        isInitialized: true,
        // Simulate offline data
      );

      final onlineState = offlineState.copyWith(
        gameSquadSpots: {
          'Game1': ['user1', 'user2']
        },
        isInitialDataLoaded: true,
        // Simulate synced online data
      );

      expect(offlineState.gameSquadSpots['Game1'], hasLength(1));
      expect(onlineState.gameSquadSpots['Game1'], hasLength(2));
      expect(onlineState.isInitialDataLoaded, isTrue);
    });

    test('permission checks across notifiers', () {
      // Test cross-notifier permission logic
      final squadState = SquadState.initial().copyWith(
        squadMemberUids: ['admin-uid', 'member-uid'],
        currentSquadData: {'owner': 'admin-uid'},
      );

      // Simulate permission check
      final isOwner = squadState.currentSquadData?['owner'] == 'admin-uid';
      expect(isOwner, isTrue);
    });

    test('async operation sequencing', () async {
      // Test async operation ordering
      final operations = <String>[];

      // Simulate async operations
      await Future.delayed(const Duration(milliseconds: 10), () {
        operations.add('operation1');
      });

      await Future.delayed(const Duration(milliseconds: 5), () {
        operations.add('operation2');
      });

      expect(operations, contains('operation1'));
      expect(operations, contains('operation2'));
    });

    test('memory leak prevention', () {
      // Test that subscriptions are properly managed
      final subscriptions = <StreamSubscription>[];

      // Simulate subscription management
      expect(subscriptions, isEmpty);
    });

    test('large data set handling', () {
      // Test performance with large data sets
      final largeMessageList = List.generate(
        1000,
        (index) => Message(
          sender: 'User$index',
          content: 'Message $index',
          timestamp: DateTime.now(),
          reactions: [],
        ),
      );

      final chatState = ChatState.initial().copyWith(
        messages: largeMessageList,
      );

      expect(chatState.messages, hasLength(1000));
    });
  });
}
*/

