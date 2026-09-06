import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/widgets/audio_message.dart';

void main() {
  testWidgets('renders play control for an audio URL', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AudioMessage(url: 'https://example.com/clip.mp3'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
}
