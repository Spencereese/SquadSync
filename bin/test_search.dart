import 'package:cod_squad_app/managers/game_manager.dart';

void main() async {
  print('Testing GameManager search functionality...');

  final gameManager = GameManager();

  // Test search with 'call' - should find Call of Duty
  print('\nSearching for "call":');
  final callResults = await gameManager.searchGames('call');
  print('Found ${callResults.length} games:');
  for (var game in callResults) {
    print('  - ${game['name']}');
  }

  // Test search with 'fort' - should find Fortnite
  print('\nSearching for "fort":');
  final fortResults = await gameManager.searchGames('fort');
  print('Found ${fortResults.length} games:');
  for (var game in fortResults) {
    print('  - ${game['name']}');
  }

  // Test search with empty query
  print('\nSearching for empty string:');
  final emptyResults = await gameManager.searchGames('');
  print('Found ${emptyResults.length} games');

  print('\nTotal available games: ${gameManager.availableGames.length}');
  print('First 5 games:');
  for (var i = 0; i < 5 && i < gameManager.availableGames.length; i++) {
    print('  - ${gameManager.availableGames[i]['name']}');
  }
}
