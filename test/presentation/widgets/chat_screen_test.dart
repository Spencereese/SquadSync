import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/message_bubble.dart';
import 'package:squad_sync/chat/models/message_data.dart';
import 'package:squad_sync/domain/entities/message.dart';

MessageData _bubble(MessageStatus status) {
  return MessageData(
    id: 'client-1',
    sender: 'Me',
    senderUid: 'me',
    text: 'hello',
    timestamp: DateTime.utc(2026, 4, 2, 12),
    status: status,
  );
}

Future<void> _pump(WidgetTester tester, MessageData data) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: data,
            isMe: true,
            showSender: false,
            showAvatar: false,
            showTimestamp: false,
            showReadIndicator: false,
            isFirstInGroup: true,
            isLastInGroup: true,
            onTap: () {},
            onLongPress: () {},
            sendingStatus: const {},
            chatType: ChatType.userGroup,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a failed outgoing bubble says tap to retry', (tester) async {
    await _pump(tester, _bubble(MessageStatus.failed));
    expect(find.text('Not sent. Tap to retry'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('sending shows a progress indicator and hides the failure copy',
      (tester) async {
    await _pump(tester, _bubble(MessageStatus.sending));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Not sent. Tap to retry'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('sent shows a check and hides the failure copy', (tester) async {
    await _pump(tester, _bubble(MessageStatus.sent));
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Not sent. Tap to retry'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
