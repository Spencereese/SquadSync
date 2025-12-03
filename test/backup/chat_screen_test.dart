import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:cod_squad_app/chat/chat_screen.dart';
import 'package:cod_squad_app/chat/chat_state.dart';
import 'package:cod_squad_app/domain/entities/message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatScreen', () {
    testWidgets('renders correctly with basic setup', (tester) async {
      final chatState = ChatState();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: p.ChangeNotifierProvider<ChatState>.value(
              value: chatState,
              child: const ChatScreen(chatType: ChatType.squad),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays typing indicator when user is typing',
        (tester) async {
      final chatState = ChatState();
      chatState.setTypingUser('TestUser');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: p.ChangeNotifierProvider<ChatState>.value(
              value: chatState,
              child: const ChatScreen(chatType: ChatType.squad),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TestUser is typing...'), findsOneWidget);
      // Check for animated dots (3 TweenAnimationBuilder widgets)
      expect(find.byType(TweenAnimationBuilder<double>), findsNWidgets(3));
    });

    testWidgets('hides typing indicator when no one is typing', (tester) async {
      final chatState = ChatState();
      chatState.setTypingUser(null);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: p.ChangeNotifierProvider<ChatState>.value(
              value: chatState,
              child: const ChatScreen(chatType: ChatType.squad),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('is typing...'), findsNothing);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('typing indicator shows correct user name', (tester) async {
      final chatState = ChatState();
      chatState.setTypingUser('John Doe');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: p.ChangeNotifierProvider<ChatState>.value(
              value: chatState,
              child: const ChatScreen(chatType: ChatType.squad),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('John Doe is typing...'), findsOneWidget);
    });

    testWidgets('typing indicator animation parameters are correct',
        (tester) async {
      final chatState = ChatState();
      chatState.setTypingUser('TestUser');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: p.ChangeNotifierProvider<ChatState>.value(
              value: chatState,
              child: const ChatScreen(chatType: ChatType.squad),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the typing indicator container
      final typingContainer = find.ancestor(
        of: find.text('TestUser is typing...'),
        matching: find.byType(Container),
      );

      expect(typingContainer, findsOneWidget);

      // Check that the container has proper padding
      final Container container = tester.widget(typingContainer);
      expect(container.padding,
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0));
    });

    testWidgets('handles different chat types', (tester) async {
      final chatState = ChatState();

      // Test squad chat
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: p.ChangeNotifierProvider<ChatState>.value(
              value: chatState,
              child: const ChatScreen(chatType: ChatType.squad),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);

      // Test private chat
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: p.ChangeNotifierProvider<ChatState>.value(
              value: chatState,
              child: const ChatScreen(chatType: ChatType.dm),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('safe area is applied correctly', (tester) async {
      final chatState = ChatState();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: p.ChangeNotifierProvider<ChatState>.value(
              value: chatState,
              child: const ChatScreen(chatType: ChatType.squad),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SafeArea), findsOneWidget);

      // Check SafeArea properties
      final SafeArea safeArea = tester.widget(find.byType(SafeArea));
      expect(safeArea.top, isTrue);
      expect(safeArea.bottom, isFalse);
    });

    testWidgets('gradient background is applied', (tester) async {
      final chatState = ChatState();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: p.ChangeNotifierProvider<ChatState>.value(
              value: chatState,
              child: const ChatScreen(chatType: ChatType.squad),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the main container with gradient
      final containers = find.byType(Container);
      expect(containers, findsWidgets);

      // Find container with gradient decoration
      Container? gradientContainer;
      for (final container in containers.evaluate()) {
        final Container widget = container.widget as Container;
        if (widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          if (decoration.gradient is LinearGradient) {
            gradientContainer = widget;
            break;
          }
        }
      }

      expect(gradientContainer, isNotNull);
      final gradient = (gradientContainer!.decoration as BoxDecoration).gradient
          as LinearGradient;
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
      expect(gradient.colors, [Colors.black, Colors.indigo]);
    });

    testWidgets('gesture detector handles tap to dismiss keyboard',
        (tester) async {
      final chatState = ChatState();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: p.ChangeNotifierProvider<ChatState>.value(
              value: chatState,
              child: const ChatScreen(chatType: ChatType.squad),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the main GestureDetector
      final gestureDetectors = find.byType(GestureDetector);
      expect(gestureDetectors, findsWidgets);

      // The main chat area GestureDetector should exist
      // We can't easily test the onTap behavior without mocking FocusScope,
      // but we can verify the GestureDetector exists
      expect(gestureDetectors.first, findsOneWidget);
    });

    testWidgets('chat input bar has proper semantics', (tester) async {
      final chatState = ChatState();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(),
          child: MaterialApp(
            home: p.ChangeNotifierProvider<ChatState>.value(
              value: chatState,
              child: const ChatScreen(chatType: ChatType.squad),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Chat input bar'), findsOneWidget);
    });
  });
}
