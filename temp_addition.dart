group('Edge Cases Integration Tests', () {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('GameNotifier handles empty search', () async {
    final gameNotifier = container.read(gameNotifierProvider.notifier);
    await container.read(gameNotifierProvider.future);
    gameNotifier.searchGames('');
    final state = await container.read(gameNotifierProvider.future);
    // Should show all games or handle empty
    expect(state.isInitialized, true);
  });

  test('SystemNotifier handles multiple notifications', () async {
    final systemNotifier = container.read(systemNotifierProvider.notifier);
    await container.read(systemNotifierProvider.future);
    // Add multiple notifications (though without auth, they won't persist)
    systemNotifier.addNotification({'message': 'Test 1', 'type': 'info'});
    systemNotifier.addNotification({'message': 'Test 2', 'type': 'warning'});
    final state = await container.read(systemNotifierProvider.future);
    // Without auth, still 0
    expect(state.notifications.length, 0);
  });
});

group('Widget Integration Tests', () {
  testWidgets('GameNotifier state updates trigger rebuilds', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              final gameState = ref.watch(gameNotifierProvider);
              return gameState.when(
                data: (state) => Text('Games: ${state.availableGames.length}'),
                loading: () => const CircularProgressIndicator(),
                error: (err, stack) => Text('Error: $err'),
              );
            },
          ),
        ),
      ),
    );

    // Wait for initialization
    await tester.pumpAndSettle();

    // Should show games count
    expect(find.textContaining('Games:'), findsOneWidget);
  });

  testWidgets('SystemNotifier notification state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              final systemState = ref.watch(systemNotifierProvider);
              return systemState.when(
                data: (state) => Text('Notifications: ${state.notifications.length}'),
                loading: () => const CircularProgressIndicator(),
                error: (err, stack) => Text('Error: $err'),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Notifications: 0'), findsOneWidget);
  });
});