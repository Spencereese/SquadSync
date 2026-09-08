import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/chat_input_bar.dart';
import 'package:squad_sync/core/fill_pin_suggestion_parser.dart';

/// PIN WAVE P1 Build slice A — Fill PIN suggestion chip.
///
/// Composer shows [FillPinSuggestion.chipLabel] only when
/// [FillPinSuggestion.shouldPropose]. Tap creates via the caller;
/// typing / dismiss never creates.
Widget _bar({
  required TextEditingController controller,
  ValueChanged<FillPinSuggestion>? onFillPinSuggestionTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ChatInputBar(
        controller: controller,
        isRecording: false,
        isUploading: false,
        onSend: () {},
        onMedia: () {},
        onRecordStart: () {},
        onRecordStop: () {},
        onPlusMenu: () {},
        onTextChanged: (_) {},
        quickReactionEmoji: '👍',
        onFillPinSuggestionTap: onFillPinSuggestionTap,
      ),
    ),
  );
}

void main() {
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('propose-worthy text shows chipLabel; narrative does not',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _bar(
        controller: controller,
        onFillPinSuggestionTap: (_) => taps++,
      ),
    );

    await tester.enterText(find.byType(TextField), 'warzone 1/4');
    await tester.pump();

    expect(find.byKey(kFillPinSuggestionChipKey), findsOneWidget);
    expect(find.text('Start Warzone 1/4'), findsOneWidget);
    expect(taps, 0, reason: 'Typing must never auto-create a pin');

    await tester.enterText(find.byType(TextField), 'we went 2/4 last night');
    await tester.pump();

    expect(find.byKey(kFillPinSuggestionChipKey), findsNothing);
    expect(find.text('Start Warzone 1/4'), findsNothing);
    expect(taps, 0);
  });

  testWidgets('bare 1/4 and warzone? show parser chipLabel', (tester) async {
    await tester.pumpWidget(
      _bar(
        controller: controller,
        onFillPinSuggestionTap: (_) {},
      ),
    );

    await tester.enterText(find.byType(TextField), '1/4');
    await tester.pump();
    expect(find.text('Start 1/4'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'warzone?');
    await tester.pump();
    expect(find.text('Start Warzone 1/4'), findsOneWidget);
  });

  testWidgets('tap creates once; dismiss/ignore creates nothing',
      (tester) async {
    final tapped = <FillPinSuggestion>[];
    await tester.pumpWidget(
      _bar(
        controller: controller,
        onFillPinSuggestionTap: tapped.add,
      ),
    );

    await tester.enterText(find.byType(TextField), 'warzone 1/4');
    await tester.pump();
    expect(tapped, isEmpty);

    await tester.tap(find.byKey(kFillPinSuggestionDismissKey));
    await tester.pump();
    expect(tapped, isEmpty);
    expect(find.byKey(kFillPinSuggestionChipKey), findsNothing);

    await tester.enterText(find.byType(TextField), '1/4');
    await tester.pump();
    expect(find.text('Start 1/4'), findsOneWidget);

    await tester.tap(find.byKey(kFillPinSuggestionChipKey));
    await tester.pump();

    expect(tapped, hasLength(1));
    expect(tapped.single.shouldPropose, isTrue);
    expect(tapped.single.chipLabel, 'Start 1/4');
    expect(tapped.single.n, 1);
    expect(tapped.single.max, 4);
    expect(find.byKey(kFillPinSuggestionChipKey), findsNothing);
  });

  testWidgets('no chip when create callback is omitted', (tester) async {
    await tester.pumpWidget(_bar(controller: controller));
    await tester.enterText(find.byType(TextField), 'warzone 1/4');
    await tester.pump();
    expect(find.byKey(kFillPinSuggestionChipKey), findsNothing);
  });

  test('composer uses parser; tap path is group-scoped createLobby', () {
    final bar = File('lib/chat/chat_input_bar.dart').readAsStringSync();
    expect(bar.contains('parseFillPinSuggestion'), isTrue);
    expect(bar.contains('onFillPinSuggestionTap'), isTrue);
    expect(
      bar.contains('createLobby'),
      isFalse,
      reason: 'Composer stays presentation; create is the chat_screen bind',
    );

    final screen = File('lib/chat/chat_screen.dart').readAsStringSync();
    expect(screen.contains('onFillPinSuggestionTap'), isTrue);
    expect(screen.contains('_createFillPinFromSuggestion'), isTrue);
    expect(
      screen.contains('threadChatGroupId'),
      isTrue,
      reason: 'Pin must bind THIS chat group, not a second lobby stack',
    );
    expect(
      RegExp(
        r'_createFillPinFromSuggestion[\s\S]*?createLobby\(',
      ).hasMatch(screen),
      isTrue,
    );
  });
}
