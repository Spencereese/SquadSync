import 'package:flutter_test/flutter_test.dart';
import '../lib/chat/chat_state.dart';

void main() {
  group('DM Chat Integration Tests', () {
    late ChatState chatState;

    setUp(() {
      chatState = ChatState();
    });

    test('ChatState DM view management', () {
      // Initially not in DM view
      expect(chatState.isDMView, false);

      // Set to DM view
      chatState.setDMView(true);
      expect(chatState.isDMView, true);

      // Set back
      chatState.setDMView(false);
      expect(chatState.isDMView, false);
    });

    test('ChatState DM unread count management', () {
      // Initially zero
      expect(chatState.dmUnreadCount, 0);

      // Set count
      chatState.setDMUnreadCount(5);
      expect(chatState.dmUnreadCount, 5);

      // Reset
      chatState.reset();
      expect(chatState.dmUnreadCount, 0);
    });

    test('ChatState reset includes DM state', () {
      // Set some state
      chatState.setDMView(true);
      chatState.setDMUnreadCount(3);

      // Reset
      chatState.reset();

      // Verify reset
      expect(chatState.isDMView, false);
      expect(chatState.dmUnreadCount, 0);
    });
  });
}
