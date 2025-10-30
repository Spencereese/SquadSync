import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:cod_squad_app/chat/chat_screen.dart';
import 'package:cod_squad_app/managers/squad_manager.dart';
import 'package:cod_squad_app/squad_state.dart';
import 'package:cod_squad_app/screens/squad_tab_screen.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late SquadManager squadManager;
  late SquadState squadState;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    squadManager = SquadManager();
    squadState = SquadState();
  });

  group('Peacock Flow Tests', () {
    testWidgets('Header card shows active squad', (WidgetTester tester) async {
      // Mock user
      when(mockAuth.currentUser).thenReturn(MockUser(uid: 'testUid'));

      // Add mock peacock
      await fakeFirestore.collection('peacocks').add({
        'hostUid': 'testUid',
        'game': {'name': 'Test Game'},
        'spots': 4,
        'claimed': ['user1'],
        'timer': Timestamp.now().add(const Duration(hours: 1)),
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            Provider<FirebaseFirestore>.value(value: fakeFirestore),
            ChangeNotifierProvider<SquadState>.value(value: squadState),
          ],
          child: const MaterialApp(home: ChatScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Your Active Squad: Test Game - 1/4 spots'),
          findsOneWidget);
    });

    testWidgets('Badge tap navigates to SquadTabScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            ChangeNotifierProvider<SquadState>.value(value: squadState),
          ],
          child: const MaterialApp(home: ChatScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the online badge
      await tester.tap(find.textContaining('Online:'));
      await tester.pumpAndSettle();

      expect(find.byType(SquadTabScreen), findsOneWidget);
    });

    test('Join lobby updates claimed list', () async {
      final peacockId = 'testPeacock';
      await fakeFirestore.collection('peacocks').doc(peacockId).set({
        'claimed': [],
      });

      await squadManager.joinLobby(peacockId, 'testUser');

      final doc =
          await fakeFirestore.collection('peacocks').doc(peacockId).get();
      expect(doc.data()!['claimed'], contains('testUser'));
    });
  });
}

class MockUser extends Mock implements User {
  @override
  final String uid;
  MockUser({required this.uid});

  @override
  String get uid => this.uid;
}
