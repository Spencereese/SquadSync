import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:squad_sync/firebase_options.dart';
import 'package:squad_sync/services/igdb_auth_service.dart';

/// Seeds Firestore with popular games from IGDB API
/// Run with: dart bin/seed_games.dart
///
/// Prerequisites:
/// 1. Run the app once with storeCredentials() uncommented in main.dart
/// 2. Then run: dart bin/seed_games.dart
void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('Starting game seeding with IGDB...');

  final igdbService = IgdbAuthService();

  // Check if credentials are stored
  final clientId = await igdbService.getClientId();
  if (clientId == null) {
    print('❌ IGDB credentials not found!');
    print('');
    print('To fix this:');
    print('1. Uncomment the storeCredentials() call in lib/main.dart');
    print('2. Run the app once to store credentials');
    print('3. Comment out the storeCredentials() call again');
    print('4. Then run: dart bin/seed_games.dart');
    print('');
    print('For prod, proxy token/search via backend to hide secret.');
    return;
  }

  const totalGames = 60; // Target number of games to seed
  final popularQueries = [
    'call of duty',
    'apex legends',
    'fortnite',
    'counter strike',
    'valorant',
    'overwatch',
    'league of legends',
    'dota 2',
    'world of warcraft',
    'minecraft',
    'grand theft auto',
    'fifa',
    'madden',
    'rocket league',
    'rainbow six siege',
    'destiny 2',
    'halo',
    'battlefield',
    'the finals',
    'escape from tarkov',
    'pubg',
    'among us',
    'roblox',
    'genshin impact',
    'cyberpunk 2077',
    'the last of us',
    'god of war',
    'spiderman',
    'assassin\'s creed',
    'far cry'
  ];

  final allGames = <Map<String, dynamic>>[];
  int totalFetched = 0;

  print('Fetching games from IGDB...');

  // Fetch games for each query
  for (final query in popularQueries) {
    if (totalFetched >= totalGames) break;

    print('Searching for: $query');
    try {
      final results = await igdbService.searchGames(query, limit: 5);
      for (final game in results) {
        if (totalFetched >= totalGames) break;
        if (!allGames.any((g) => g['slug'] == game['slug'])) {
          allGames.add(game);
          totalFetched++;
        }
      }

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('Error fetching games for "$query": $e');
      // Continue with next query
    }
  }

  print('Fetched ${allGames.length} unique games. Saving to Firestore...');

  // Save to Firestore
  final batch = FirebaseFirestore.instance.batch();
  for (final game in allGames) {
    final docRef =
        FirebaseFirestore.instance.collection('games').doc(game['slug']);
    batch.set(docRef, game, SetOptions(merge: true));
  }

  try {
    await batch.commit();
    print('✅ Successfully seeded ${allGames.length} games to Firestore!');
    print('Sample games:');
    for (var i = 0; i < 5 && i < allGames.length; i++) {
      print('  - ${allGames[i]['name']} (${allGames[i]['slug']})');
    }
  } catch (e) {
    print('❌ Error saving to Firestore: $e');
  }
}
