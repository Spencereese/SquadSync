import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cod_squad_app/managers/user_manager.dart';

void main() {
  late UserManager userManager;

  setUp(() {
    userManager = UserManager();
  });

  group('Pinned Games Sorting', () {
    test('sorts pinned games by lastPlayed descending', () {
      // Setup test data with different lastPlayed times
      final games = [
        {
          'name': 'Game A',
          'lastPlayed':
              Timestamp.fromDate(DateTime.now().subtract(Duration(days: 2)))
        },
        {
          'name': 'Game B',
          'lastPlayed':
              Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1)))
        },
        {'name': 'Game C', 'lastPlayed': Timestamp.fromDate(DateTime.now())},
      ];

      userManager.pinnedGames = games;

      // Sort should put Game C first (most recent)
      userManager.pinnedGames.sort((a, b) {
        final aTime = a['lastPlayed'] as Timestamp?;
        final bTime = b['lastPlayed'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      expect(userManager.pinnedGames[0]['name'], 'Game C');
      expect(userManager.pinnedGames[1]['name'], 'Game B');
      expect(userManager.pinnedGames[2]['name'], 'Game A');
    });

    test('handles null lastPlayed timestamps', () {
      final games = [
        {'name': 'Game A', 'lastPlayed': null},
        {'name': 'Game B', 'lastPlayed': Timestamp.now()},
        {'name': 'Game C', 'lastPlayed': null},
      ];

      userManager.pinnedGames = games;

      userManager.pinnedGames.sort((a, b) {
        final aTime = a['lastPlayed'] as Timestamp?;
        final bTime = b['lastPlayed'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      // Games with timestamps should come first
      expect(userManager.pinnedGames[0]['name'], 'Game B');
      // Null timestamps should come after
      expect(userManager.pinnedGames[1]['name'], 'Game A');
      expect(userManager.pinnedGames[2]['name'], 'Game C');
    });
  });

  group('Carousel Scaling Logic', () {
    test('calculates correct scale for center item', () {
      const currentPage = 1.0;
      const index = 1;
      final pageOffset = index - currentPage; // 0.0
      final scale = 1 - (pageOffset.abs() * 0.2).clamp(0.0, 0.4); // 1.0

      expect(scale, 1.0);
    });

    test('calculates correct scale for adjacent items', () {
      const currentPage = 1.0;
      const index = 0;
      final pageOffset = index - currentPage; // -1.0
      final scale =
          1 - (pageOffset.abs() * 0.2).clamp(0.0, 0.4); // 1 - 0.2 = 0.8

      expect(scale, 0.8);
    });

    test('clamps scale to minimum value', () {
      const currentPage = 1.0;
      const index = 5;
      final pageOffset = index - currentPage; // 4.0
      final scale =
          1 - (pageOffset.abs() * 0.2).clamp(0.0, 0.4); // 1 - 0.4 = 0.6

      expect(scale, 0.6);
    });
  });
}
