import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../lib/chat/widgets/message_reactions.dart';

void main() {
  testWidgets('IMessageReactionsBar shows emoji picker when smiley tapped',
      (WidgetTester tester) async {
    bool emojiSelected = false;
    String selectedEmoji = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              IMessageReactionsBar(
                position: const Offset(100, 200),
                isOutgoing: true,
                onEmojiSelect: (emoji) {
                  emojiSelected = true;
                  selectedEmoji = emoji;
                },
                onDismiss: () {},
                quickReactions: ['👍', '❤️', '😂'],
              ),
            ],
          ),
        ),
      ),
    );

    // Wait for animations to complete
    await tester.pumpAndSettle();

    // Find the greyed-out smiley button (first one)
    final smileyFinder = find.text('😊').first;
    expect(smileyFinder, findsOneWidget);

    // Tap the smiley to open emoji picker
    await tester.tap(smileyFinder);
    await tester.pumpAndSettle();

    // Verify emoji picker is shown
    expect(find.byType(EmojiPicker), findsOneWidget);

    // Tap an emoji from the picker
    final emojiButton =
        find.text('😀'); // Common emoji that should be in picker
    if (emojiButton.evaluate().isNotEmpty) {
      await tester.tap(emojiButton);
      await tester.pumpAndSettle();

      // Verify emoji was selected
      expect(emojiSelected, true);
      expect(selectedEmoji, '😀');
    }
  });

  testWidgets('MessageReactions displays reaction counts correctly',
      (WidgetTester tester) async {
    final reactions = [
      {'reaction': '👍', 'userUid': 'user1'},
      {'reaction': '👍', 'userUid': 'user2'},
      {'reaction': '❤️', 'userUid': 'user3'},
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageReactions(
            reactions: reactions,
            isOutgoing: true,
          ),
        ),
      ),
    );

    // Should show 👍2 and ❤️
    expect(find.text('👍2'), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
  });
}
