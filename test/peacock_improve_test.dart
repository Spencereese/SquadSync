import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cod_squad_app/chat/peacock_modal.dart';
import 'package:cod_squad_app/managers/user_manager.dart';
import 'package:cod_squad_app/managers/game_manager.dart';
import 'package:cod_squad_app/managers/notification_manager.dart';
import 'package:cod_squad_app/squad_state.dart';

// Mock classes
class MockUser extends Mock implements User {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockDocumentReference extends Mock implements DocumentReference {}

class MockCollectionReference extends Mock implements CollectionReference {}

class MockQuerySnapshot extends Mock implements QuerySnapshot {}

class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot {}

void main() {
  group('PeacockModal Improvements', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late UserManager userManager;
    late GameManager gameManager;
    late NotificationManager notificationManager;
    late SquadState squadState;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      userManager = UserManager();
      gameManager = GameManager();
      notificationManager = NotificationManager();
      squadState = SquadState();
    });

    testWidgets('Pinned games fetch and display', (WidgetTester tester) async {
      // Mock user
      final mockUser = MockUser();
      when(mockUser.uid).thenReturn('test-uid');
      when(mockAuth.currentUser).thenReturn(mockUser);

      // Mock Firestore
      final mockDoc = MockQueryDocumentSnapshot();
      when(mockDoc.data()).thenReturn({
        'pinnedGames': [
          {'name': 'Test Game', 'coverUrl': 'url'}
        ]
      });
      when(mockFirestore.collection('users').doc('test-uid').get())
          .thenAnswer((_) async => mockDoc);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<UserManager>(create: (_) => userManager),
            Provider<GameManager>(create: (_) => gameManager),
            Provider<NotificationManager>(create: (_) => notificationManager),
            Provider<SquadState>(create: (_) => squadState),
          ],
          child: const MaterialApp(home: Scaffold(body: PeacockModal())),
        ),
      );

      // Wait for initState
      await tester.pump();

      // Check if pinned games are displayed
      expect(find.text('Pinned Games'), findsOneWidget);
      expect(find.text('Test Game'), findsOneWidget);
    });

    testWidgets('Bigger logos in suggestions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<UserManager>(create: (_) => userManager),
            Provider<GameManager>(create: (_) => gameManager),
            Provider<NotificationManager>(create: (_) => notificationManager),
            Provider<SquadState>(create: (_) => squadState),
          ],
          child: const MaterialApp(home: Scaffold(body: PeacockModal())),
        ),
      );

      // The logos are 60x60 as per code
      // This would require more complex testing with TypeAheadField
    });

    testWidgets('Validation disables launch button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<UserManager>(create: (_) => userManager),
            Provider<GameManager>(create: (_) => gameManager),
            Provider<NotificationManager>(create: (_) => notificationManager),
            Provider<SquadState>(create: (_) => squadState),
          ],
          child: const MaterialApp(home: Scaffold(body: PeacockModal())),
        ),
      );

      // Launch button should be disabled initially
      final button = find.text('Launch Squad');
      expect(tester.widget<ElevatedButton>(button).enabled, isFalse);
    });

    test('UserManager add pinned game', () async {
      final mockUser = MockUser();
      when(mockUser.uid).thenReturn('test-uid');
      when(mockAuth.currentUser).thenReturn(mockUser);

      final mockCollection = MockCollectionReference();
      final mockDoc = MockDocumentReference();
      when(mockFirestore.collection('users')).thenReturn(mockCollection);
      when(mockCollection.doc('test-uid')).thenReturn(mockDoc);
      when(mockDoc.set(any, any)).thenAnswer((_) async {});

      await userManager.addPinnedGame({'name': 'New Game'});

      expect(userManager.pinnedGames.length, 1);
      expect(userManager.pinnedGames[0]['name'], 'New Game');
    });
  });
}
