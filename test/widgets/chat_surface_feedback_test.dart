import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/widgets/chat_surface_feedback.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('ChatScreen thread', () {
    testWidgets('empty copy is arm length with no spinner', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ChatSurfaceFeedback(
            kind: ChatSurfaceKind.thread,
            phase: ChatSurfacePhase.empty,
          ),
        ),
      );

      expect(find.byKey(const Key('chat-thread-empty')), findsOneWidget);
      expect(find.text(kChatThreadEmptyCopy), findsOneWidget);
      expect(find.text(kChatThreadEmptyHint), findsOneWidget);
      expect(find.byKey(const Key('chat-thread-empty-hint')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('chat-thread-retry')), findsNothing);
    });

    testWidgets('error copy offers Retry and never a spinner', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          ChatSurfaceFeedback(
            kind: ChatSurfaceKind.thread,
            phase: ChatSurfacePhase.error,
            error: 'offline',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.byKey(const Key('chat-thread-error')), findsOneWidget);
      expect(find.text(kChatThreadErrorCopy), findsOneWidget);
      expect(find.text(kChatSurfaceErrorHint), findsOneWidget);
      expect(find.text('offline'), findsOneWidget);
      expect(find.byKey(const Key('chat-thread-retry')), findsOneWidget);
      expect(find.text(kChatSurfaceRetryLabel), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.byKey(const Key('chat-thread-retry')));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('offline copy offers Retry and never a spinner',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          ChatSurfaceFeedback(
            kind: ChatSurfaceKind.thread,
            phase: ChatSurfacePhase.error,
            isOffline: true,
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text(kChatSurfaceOfflineCopy), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text(kChatSurfaceRetryLabel));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('loading is in-flight copy, not a hung spinner without text',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ChatSurfaceFeedback(
            kind: ChatSurfaceKind.thread,
            phase: ChatSurfacePhase.loading,
          ),
        ),
      );

      expect(find.byKey(const Key('chat-thread-loading')), findsOneWidget);
      expect(find.text(kChatThreadLoadingCopy), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('chat-thread-retry')), findsNothing);
    });
  });

  group('shared chat list', () {
    testWidgets('empty copy is arm length with no spinner', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ChatSurfaceFeedback(
            kind: ChatSurfaceKind.list,
            phase: ChatSurfacePhase.empty,
          ),
        ),
      );

      expect(find.byKey(const Key('chat-list-empty')), findsOneWidget);
      expect(find.text(kChatListEmptyCopy), findsOneWidget);
      expect(find.text(kChatListEmptyHint), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('chat-list-retry')), findsNothing);
    });

    testWidgets('error copy offers Retry that re-fetches', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          ChatSurfaceFeedback(
            kind: ChatSurfaceKind.list,
            phase: ChatSurfacePhase.error,
            error: 'timeout',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.byKey(const Key('chat-list-error')), findsOneWidget);
      expect(find.text(kChatListErrorCopy), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.byKey(const Key('chat-list-retry')));
      await tester.pump();
      expect(retried, isTrue);
    });
  });
}
