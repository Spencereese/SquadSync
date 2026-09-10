import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/widgets/neon_chat_app_bar.dart';

void main() {
  testWidgets('loading chip stays one line in a tight header slot',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 72,
              height: 36,
              child: ChatHeaderStatusChip(
                status: ChatHeaderStatus.loading,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Load'), findsOneWidget);
    expect(find.textContaining('ing'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('pending chip does not wrap or overflow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 88,
              height: 36,
              child: ChatHeaderStatusChip(
                status: ChatHeaderStatus.pending,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Load'), findsNothing);
  });

  testWidgets('idle chip takes no space', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatHeaderStatusChip(status: ChatHeaderStatus.idle),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Load'), findsNothing);
    expect(find.text('Pending'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });
}
