import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../squad_state_notifier.dart';
import '../../managers/game_manager.dart' as gm;

/// GameSelector component - handles game selection, display, and switching
/// Extracted from the monolithic SquadTab to improve maintainability
class GameSelector extends ConsumerWidget {
  final String? gameName;
  final Map<String, dynamic>? game;
  final VoidCallback? onGameTap;

  const GameSelector({
    super.key,
    this.gameName,
    this.game,
    this.onGameTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadState = ref.watch(squadStateNotifierProvider);
    final notifier = ref.read(squadStateNotifierProvider.notifier);
    final currentGame = squadState.currentGame ?? game;

    return GestureDetector(
      onTap:
          onGameTap ?? () => _showGameSelectionDialog(context, notifier, ref),
      child: SizedBox(
        width: 220,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [_buildGameLogo(currentGame)],
        ),
      ),
    );
  }

  Widget _buildGameLogo(Map<String, dynamic>? currentGame) {
    Widget logo;

    if (currentGame != null && currentGame['coverUrl'] != null) {
      logo = Container(
        width: 200,
        height: 140,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(currentGame['coverUrl']),
            fit: BoxFit.contain,
          ),
        ),
      );
    } else {
      final assetName =
          getAssetName(currentGame?['name']) ?? getAssetName(this.gameName);
      if (assetName != null) {
        logo = Image.asset(
          'assets/images/$assetName',
          width: 200,
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.gamepad, size: 100, color: Colors.cyanAccent),
        );
      } else if (currentGame?['logo'] != null) {
        // Fallback to old asset logo field
        logo = Image.asset(
          currentGame!['logo'],
          width: 200,
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.gamepad, size: 100, color: Colors.cyanAccent),
        );
      } else {
        logo = const Icon(
          Icons.gamepad,
          size: 100,
          color: Colors.cyanAccent,
        );
      }
    }

    return logo;
  }

  void _showGameSelectionDialog(
      BuildContext context, SquadStateNotifier squadState, WidgetRef ref) {
    final TextEditingController gameController = TextEditingController();
    Map<String, dynamic>? selectedGame;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          title: const Text(
            'Switch Game',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: gameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search for a game...',
                    hintStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.cyanAccent),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.cyanAccent),
                    ),
                  ),
                  onChanged: (value) async {
                    if (value.isNotEmpty) {
                      final results = await ref
                          .read(gm.gameManagerProvider.notifier)
                          .fetchGamesFromIGDB(value);
                      if (results.isNotEmpty) {
                        setState(() {
                          selectedGame = results.first;
                        });
                      }
                    }
                  },
                ),
                if (selectedGame != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (selectedGame!['coverUrl'] != null)
                          Image.network(
                            selectedGame!['coverUrl'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.gamepad,
                                    color: Colors.cyanAccent),
                          )
                        else
                          const Icon(Icons.gamepad, color: Colors.cyanAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedGame!['name'] ?? 'Unknown Game',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (selectedGame!['summary'] != null &&
                                  selectedGame!['summary']
                                      .toString()
                                      .isNotEmpty)
                                Text(
                                  selectedGame!['summary'].toString(),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: selectedGame != null
                  ? () {
                      ref
                          .read(squadStateNotifierProvider.notifier)
                          .setCurrentGame(selectedGame);
                      // Mark fields as changed for persistence
                      ref
                          .read(squadStateNotifierProvider.notifier)
                          .persistenceManager
                          .markFieldChanged('currentGame');
                      // ref.read(squadStateNotifierProvider.notifier).updateFirestoreAsync();
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Switched to ${selectedGame!['name']}')),
                      );
                    }
                  : null,
              child: Text(
                'Switch',
                style: TextStyle(
                  color: selectedGame != null ? Colors.cyanAccent : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? getAssetName(String? gameName) {
    if (gameName == null) return null;

    // Normalize the game name for asset lookup
    final normalizedName = gameName
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('®', '')
        .replaceAll('™', '');

    // Map of game names to asset names
    final assetMap = {
      'callofduty': 'cod_logo.png',
      'callofdutymodernwarfareiii': 'cod_logo.png',
      'callofdutymodernwarfare3': 'cod_logo.png',
      'callofdutymodernwarfareii': 'cod_logo.png',
      'callofdutymodernwarfare2': 'cod_logo.png',
      'callofdutyblackopsiii': 'cod_logo.png',
      'callofdutyblackops3': 'cod_logo.png',
      'callofdutyblackopsii': 'cod_logo.png',
      'callofdutyblackops2': 'cod_logo.png',
      'callofdutyblackops': 'cod_logo.png',
      'callofdutyworldatwar': 'cod_logo.png',
      'callofduty4modernwarfare': 'cod_logo.png',
      'callofduty2': 'cod_logo.png',
      'apexlegends': 'apex_legends_logo.png',
      'apex': 'apex_legends_logo.png',
      'valorant': 'valorant_logo.png',
      'leagueoflegends': 'lol_logo.png',
      'league': 'lol_logo.png',
      'lol': 'lol_logo.png',
      'counterstrikeglobaloffensive': 'csgo_logo.png',
      'counterstrike': 'csgo_logo.png',
      'csgo': 'csgo_logo.png',
      'cs2': 'csgo_logo.png',
      'counterstrike2': 'csgo_logo.png',
      'overwatch2': 'overwatch_logo.png',
      'overwatch': 'overwatch_logo.png',
      'fortnite': 'fortnite_logo.png',
      'rocketleague': 'rocket_league_logo.png',
      'rainbowsixsiege': 'r6_logo.png',
      'rainbow6': 'r6_logo.png',
      'r6': 'r6_logo.png',
      'destiny2': 'destiny_logo.png',
      'destiny': 'destiny_logo.png',
      'halo': 'halo_logo.png',
      'haloinfinite': 'halo_logo.png',
      'halomcc': 'halo_logo.png',
      'minecraft': 'minecraft_logo.png',
      'amongus': 'among_us_logo.png',
      'among': 'among_us_logo.png',
      'fallguys': 'fall_guys_logo.png',
      'fall': 'fall_guys_logo.png',
      'jackbox': 'jackbox_logo.png',
      'jackboxparty': 'jackbox_logo.png',
      'jackboxpartypack': 'jackbox_logo.png',
      'thesims4': 'sims_logo.png',
      'sims4': 'sims_logo.png',
      'sims': 'sims_logo.png',
      'worldofwarcraft': 'wow_logo.png',
      'wow': 'wow_logo.png',
      'diabloiii': 'diablo_logo.png',
      'diablo3': 'diablo_logo.png',
      'diablo': 'diablo_logo.png',
      'starcraftii': 'sc_logo.png',
      'starcraft2': 'sc_logo.png',
      'sc2': 'sc_logo.png',
      'hearthstone': 'hearthstone_logo.png',
      'warcraft': 'wow_logo.png',
      'pokemon': 'pokemon_logo.png',
      'animalcrossing': 'animal_crossing_logo.png',
      'mariokart': 'mario_kart_logo.png',
      'supermario': 'mario_logo.png',
      'marioparty': 'mario_party_logo.png',
      'splatoon': 'splatoon_logo.png',
      'fireemblem': 'fire_emblem_logo.png',
      'xenoblade': 'xenoblade_logo.png',
      'monsterhunter': 'monster_hunter_logo.png',
      'monsterhunterworld': 'monster_hunter_logo.png',
      'monsterhunterrise': 'monster_hunter_logo.png',
      'monsterhuntersunbreak': 'monster_hunter_logo.png',
      'sekiro': 'sekiro_logo.png',
      'bloodborne': 'bloodborne_logo.png',
      'darksouls': 'dark_souls_logo.png',
      'darksouls3': 'dark_souls_logo.png',
      'darksouls2': 'dark_souls_logo.png',
      'darksoulsremastered': 'dark_souls_logo.png',
      'demonssouls': 'demons_souls_logo.png',
      'soulsborne': 'bloodborne_logo.png',
      'soulslike': 'dark_souls_logo.png',
      'finalfantasy': 'ff_logo.png',
      'finalfantasyvii': 'ff7_logo.png',
      'finalfantasy7': 'ff7_logo.png',
      'ff7': 'ff7_logo.png',
      'ff7remake': 'ff7_logo.png',
      'kingdomhearts': 'kingdom_hearts_logo.png',
      'kh': 'kingdom_hearts_logo.png',
      'persona': 'persona_logo.png',
      'persona5': 'persona_logo.png',
      'p5': 'persona_logo.png',
      'dragonquest': 'dq_logo.png',
      'dq': 'dq_logo.png',
      'tales': 'tales_logo.png',
      'talesofphantasia': 'tales_logo.png',
      'grandia': 'grandia_logo.png',
      'chrono': 'chrono_logo.png',
      'chronotrigger': 'chrono_logo.png',
      'earthbound': 'earthbound_logo.png',
      'mother': 'earthbound_logo.png',
      'superpapermario': 'paper_mario_logo.png',
      'papermario': 'paper_mario_logo.png',
      'luigi': 'luigi_logo.png',
      'luigismansion': 'luigi_logo.png',
      'pikmin': 'pikmin_logo.png',
      'metroid': 'metroid_logo.png',
      'metroiddread': 'metroid_logo.png',
      'metroidprime': 'metroid_logo.png',
      'castlevania': 'castlevania_logo.png',
      'megaman': 'megaman_logo.png',
      'streetfighter': 'street_fighter_logo.png',
      'sf': 'street_fighter_logo.png',
      'tekken': 'tekken_logo.png',
      'soulcalibur': 'soul_calibur_logo.png',
      'deadoralive': 'doa_logo.png',
      'doa': 'doa_logo.png',
      'virtuafighter': 'virtua_fighter_logo.png',
      'vf': 'virtua_fighter_logo.png',
      'guiltygear': 'guilty_gear_logo.png',
      'gg': 'guilty_gear_logo.png',
      'blazblue': 'blazblue_logo.png',
      'bb': 'blazblue_logo.png',
      'undernightinbirth': 'under_night_logo.png',
      'unin': 'under_night_logo.png',
      'meltyblood': 'melty_blood_logo.png',
      'mb': 'melty_blood_logo.png',
      'arcanaheart': 'arcana_heart_logo.png',
      'ah': 'arcana_heart_logo.png',
      'kof': 'kof_logo.png',
      'kingoffighters': 'kof_logo.png',
      'samurayshodown': 'samurai_shodown_logo.png',
      'fatalfury': 'fatal_fury_logo.png',
      'ff': 'fatal_fury_logo.png',
      'artoffighting': 'art_of_fighting_logo.png',
      'aof': 'art_of_fighting_logo.png',
      'metalslug': 'metal_slug_logo.png',
      'ms': 'metal_slug_logo.png',
      'ikariwarriors': 'ikari_logo.png',
      'ikari': 'ikari_logo.png',
      'twincobra': 'twin_cobra_logo.png',
      'gradius': 'gradius_logo.png',
      'rtype': 'rtype_logo.png',
      'thundercross': 'thunder_cross_logo.png',
      'salamander': 'salamander_logo.png',
      'lifeforce': 'lifeforce_logo.png',
      'xevious': 'xevious_logo.png',
      'bosconian': 'bosconian_logo.png',
      'gaplus': 'gaplus_logo.png',
      'galaga': 'galaga_logo.png',
      'pacman': 'pacman_logo.png',
      'digdug': 'digdug_logo.png',
      'donkeykong': 'donkey_kong_logo.png',
      'dk': 'donkey_kong_logo.png',
      'frogger': 'frogger_logo.png',
      'centipede': 'centipede_logo.png',
      'millipede': 'millipede_logo.png',
      'tempest': 'tempest_logo.png',
      'asteroids': 'asteroids_logo.png',
      'battlezone': 'battlezone_logo.png',
      'redbaron': 'red_baron_logo.png',
      'spaceinvaders': 'space_invaders_logo.png',
      'defender': 'defender_logo.png',
      'robotron': 'robotron_logo.png',
      'joust': 'joust_logo.png',
      'qbert': 'qbert_logo.png',
      'burgertime': 'burgertime_logo.png',
      'rallyx': 'rallyx_logo.png',
      'trackandfield': 'track_field_logo.png',
    };

    return assetMap[normalizedName];
  }
}
