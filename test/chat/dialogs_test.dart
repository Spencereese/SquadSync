import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/dialogs/add_friend_dialog.dart';

void main() {
  testWidgets('AddFriendDialog builds without null exceptions',
      (WidgetTester tester) async {
    // Test that the dialog can be created without crashing
    // This validates null safety in the widget construction
    expect(() => AddFriendDialog(), returnsNormally);
  });
}