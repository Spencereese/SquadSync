import 'package:flutter/material.dart';import 'package:flutter/material.dart';import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';import 'package:flutter_test/flutter_test.dart';import 'package:flutter_test/flutter_test.dart';

import 'package:mockito/mockito.dart';

import 'package:cod_squad_app/screens/squad_tab_screen.dart';import 'package:provider/provider.dart';import 'package:provider/provider.dart';

import 'package:cod_squad_app/managers/squad_manager.dart';

import 'package:cod_squad_app/squad_state.dart';import 'package:mockito/mockito.dart';import 'package:mockito/mockito.dart';



// Mock classesimport '../lib/screens/squad_tab_screen.dart';import 'package:firebase_auth/firebase_auth.dart';

class MockSquadManager extends Mock implements SquadManager {}

import 'package:cod_squad_app/managers/squad_manager.dart';import 'package:cloud_firestore/cloud_firestore.dart';

class MockSquadState extends Mock implements SquadState {

  @overrideimport '../lib/squad_state.dart';import 'package:firebase_core/firebase_core.dart';

  @override
  String? get selectedSquadId => 'test-squad';

import '../lib/screens/squad_tab_screen.dart';

  @override

  List<String> get getFilteredMembers => ['Alice', 'Bob', 'Charlie'];// Mock classesimport '../lib/managers/squad_manager.dart';

}

class MockSquadManager extends Mock implements SquadManager {}import 'package:cod_squad_app/squad_state.dart';

void main() {

  late MockSquadManager mockSquadManager;

  late MockSquadState mockSquadState;

class MockSquadState extends Mock implements SquadState {// Mock classes

  setUp(() {

    mockSquadManager = MockSquadManager();  @overrideclass MockUser extends Mock implements User {

    mockSquadState = MockSquadState();

  });  String? get selectedSquadId => 'test-squad';  @override



  testWidgets('SquadTabScreen shows basic structure', (WidgetTester tester) async {  String get uid => 'test-uid';

    await tester.pumpWidget(

      MaterialApp(  @override}

        home: MultiProvider(

          providers: [  List<String> get getFilteredMembers => ['Alice', 'Bob', 'Charlie'];

            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),

            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),}class MockFirebaseAuth extends Mock implements FirebaseAuth {

          ],

          child: const SquadTabScreen(),  @override

        ),

      ),void main() {  User? get currentUser => MockUser();

    )

  late MockSquadManager mockSquadManager;}

    // Wait for the widget to build

    await tester.pumpAndSettle();  late MockSquadState mockSquadState;



    // Check that the screen shows the expected titleclass MockSquadManager extends Mock implements SquadManager {

    expect(find.text('Squad Lobbies'), findsOneWidget);

    expect(find.byType(FloatingActionButton), findsOneWidget);  setUp(() {  @override

  });

}    mockSquadManager = MockSquadManager();  Stream<QuerySnapshot> getActiveLobbiesStream() {

    mockSquadState = MockSquadState();    return Stream.value(MockQuerySnapshot());

  })  }



  testWidgets('SquadTabScreen shows basic structure', (WidgetTester tester) async {  @override

    await tester.pumpWidget(  Future<void> joinLobby(String peacockId, String userId) async {}

      MaterialApp(}

        home: MultiProvider(

          providers: [class MockQuerySnapshot extends Mock implements QuerySnapshot {

            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),  @override

            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),  List<QueryDocumentSnapshot> get docs => [];

          ],}

          child: const SquadTabScreen(),

        ),class MockSquadState extends Mock implements SquadState {

      ),  @override

    );  String? get selectedSquadId => 'test-squad';



    // Wait for the widget to build  @override

    await tester.pumpAndSettle();  List<String> get getFilteredMembers => ['Alice', 'Bob', 'Charlie'];

}

    // Check that the screen shows the expected title

    expect(find.text('Squad Lobbies'), findsOneWidget);void main() {

    expect(find.byType(FloatingActionButton), findsOneWidget);  TestWidgetsFlutterBinding.ensureInitialized();

  });

}  late MockFirebaseAuth mockAuth;
  late MockSquadManager mockSquadManager;
  late MockSquadState mockSquadState;

  setUpAll(() async {
    // Initialize Firebase for tests
    await Firebase.initializeApp();
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockSquadManager = MockSquadManager();
    mockSquadState = MockSquadState();
  });

  testWidgets('SquadTabScreen shows basic structure', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
          ],
          child: const SquadTabScreen(),
        ),
      ),
    );

    // Wait for the widget to build
    await tester.pumpAndSettle();

    // Check that the screen shows the expected title
    expect(find.text('Squad Lobbies'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
    expect(find.text('Member Status'), findsOneWidget);
  });

  testWidgets('Active Lobbies section shows empty state when no lobbies', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
          ],
          child: const SquadTabScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No active games—start one?'), findsOneWidget);
  });

  testWidgets('Member Status section shows squad members', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
          ],
          child: const SquadTabScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);
  });
}
