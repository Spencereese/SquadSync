import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cod_squad_app/screens/squad_tab_screen.dart';
import 'package:cod_squad_app/managers/squad_manager.dart';
import 'package:cod_squad_app/chat/peacock_modal.dart';

// Mock classes
class MockUser extends Mock implements User {
  @override
  String get uid => 'test-uid';
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  User? get currentUser => MockUser();
}

class MockSquadManager extends Mock implements SquadManager {
  @override
  Stream<QuerySnapshot> getActiveLobbiesStream() {
    // Return an empty stream for testing empty state
    return Stream.value(MockQuerySnapshot());
  }

  @override
  Future<void> joinLobby(String peacockId, String userId) async {
    // Mock implementation
  }
}

class MockQuerySnapshot extends Mock implements QuerySnapshot {
  @override
  List<QueryDocumentSnapshot> get docs => [];
}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockSquadManager mockSquadManager;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockSquadManager = MockSquadManager();
  });

  testWidgets('SquadTabScreen displays empty state with CTA',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            Provider<SquadManager>.value(value: mockSquadManager),
          ],
          child: const SquadTabScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No active lobbies—start one?'), findsOneWidget);
    expect(find.text('Tap the + button below'), findsOneWidget);
  });

  testWidgets('SquadTabScreen shows FAB for starting new lobby',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            Provider<SquadManager>.value(value: mockSquadManager),
          ],
          child: const SquadTabScreen(),
        ),
      ),
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('FAB opens PeacockModal bottom sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            Provider<SquadManager>.value(value: mockSquadManager),
          ],
          child: const SquadTabScreen(),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Check if PeacockModal is shown
    expect(find.byType(PeacockModal), findsOneWidget);
  });
}
