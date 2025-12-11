import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/auth_service_supabase.dart';
import 'dart:convert';
import '../presentation/notifiers/user_squads_notifier.dart';
import '../presentation/notifiers/current_lobby_notifier.dart';
import '../screens/squad_detail_screen.dart';
import '../core/app_theme.dart';
import '../services/squad_auto_selector.dart';
import '../core/injection.dart';

class LobbiesScreen extends ConsumerStatefulWidget {
  const LobbiesScreen({super.key});

  @override
  ConsumerState<LobbiesScreen> createState() => _LobbiesScreenState();
}

class _LobbiesScreenState extends ConsumerState<LobbiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(userSquadsProvider).when(
          data: (squads) {
            final filteredSquads = _searchQuery.isEmpty
                ? squads
                : squads
                    .where((squad) =>
                        squad.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        (squad.primaryGameName
                                ?.toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ??
                            false))
                    .toList();

            return Theme(
              data: AppTheme.dark(),
              child: Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  title: const Text('My Squads'),
                  backgroundColor: Colors.black,
                  elevation: 0,
                ),
                body: RefreshIndicator(
                  onRefresh: () async {
                    // Call autoSelectSquad if in a public squad
                    final currentSquadId = ref.read(currentLobbyIdProvider);
                    if (currentSquadId != null) {
                      await autoSelectSquad(ref);
                    }
                  },
                  color: Colors.cyanAccent,
                  backgroundColor: Colors.black,
                  child: filteredSquads.isEmpty && _searchQuery.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          children: [
                            // Search bar
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Search squads...',
                                  hintStyle:
                                      const TextStyle(color: Colors.white70),
                                  prefixIcon: const Icon(Icons.search,
                                      color: Colors.white70),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withValues(alpha: 0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                              ),
                            ),
                            // Squads list
                            Expanded(
                              child: filteredSquads.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No squads found',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      itemCount: filteredSquads.length,
                                      itemBuilder: (context, index) {
                                        final squad = filteredSquads[index];
                                        return _buildSquadCard(
                                            context, ref, squad);
                                      },
                                    ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
          loading: () => const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            ),
          ),
          error: (error, stack) {
            debugPrint('Firestore error in squads: $error');
            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Text(
                  'Error loading squads: $error',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          },
        );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            'No squads yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create your first squad or join one via invite code',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showCreateSquadDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create Squad'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _showJoinSquadDialog(context),
                icon: const Icon(Icons.login),
                label: const Text('Join via Code'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.cyanAccent),
                  foregroundColor: Colors.cyanAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquadCard(
      BuildContext context, WidgetRef ref, SquadSummary squad) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Set current squad
          ref.read(currentLobbyIdProvider.notifier).state = squad.id;

          // Navigate to SquadDetailScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SquadDetailScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Leading: Game icon or stacked member avatars
              SizedBox(
                width: 50,
                height: 50,
                child: squad.primaryGameName != null
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.videogame_asset,
                          color: Colors.cyanAccent,
                          size: 24,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.group,
                          color: Colors.purpleAccent,
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      squad.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      squad.primaryGameName != null
                          ? "${squad.primaryGameName} • ${squad.activeSpots ?? 0}/${squad.maxSpots ?? 0}"
                          : "Just Vibes",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Trailing: last activity time + unread badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatLastActivity(squad.lastActivity),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  if (squad.unreadCount != null && squad.unreadCount! > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        squad.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadPopularGames() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/popular_games.json');
      final List<dynamic> data = json.decode(jsonString);
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      // Return empty list if loading fails
      return [];
    }
  }

  void _showCreateSquadDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController gameController = TextEditingController();
    Map<String, dynamic>? selectedGame;
    int maxSpots = 4; // Default max spots
    List<Map<String, dynamic>> popularGames = [];
    bool isLoadingGames = true;

    // Load popular games from JSON
    _loadPopularGames().then((games) {
      popularGames = games;
      isLoadingGames = false;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'Create New Squad',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Squad Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyanAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Game selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Game',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TypeAheadField<Map<String, dynamic>>(
                          controller: gameController,
                          builder: (context, controller, focusNode) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Type or select a game...',
                                hintStyle:
                                    const TextStyle(color: Colors.white54),
                                suffixIcon: isLoadingGames
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.cyanAccent,
                                            ),
                                          ),
                                        ),
                                      )
                                    : null,
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white70),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.cyanAccent),
                                ),
                              ),
                            );
                          },
                          suggestionsCallback: (pattern) async {
                            // Filter popular games by pattern
                            if (pattern.isEmpty) {
                              return popularGames.take(10).toList();
                            }

                            final filtered = popularGames.where((game) {
                              final name =
                                  (game['name'] as String? ?? '').toLowerCase();
                              return name.contains(pattern.toLowerCase());
                            }).toList();

                            return filtered.isEmpty
                                ? []
                                : filtered.take(10).toList();
                          },
                          itemBuilder: (context, suggestion) {
                            final coverUrl =
                                suggestion['cover']?['url'] as String?;
                            return ListTile(
                              leading: coverUrl != null
                                  ? Image.network(
                                      'https:$coverUrl'
                                          .replaceAll('t_thumb', 't_cover_big'),
                                      width: 40,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.videogame_asset,
                                                  color: Colors.white70),
                                    )
                                  : const Icon(Icons.videogame_asset,
                                      color: Colors.white70),
                              title: Text(
                                suggestion['name'] as String? ?? '',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: suggestion['genres'] != null
                                  ? Text(
                                      (suggestion['genres'] as List)
                                          .map((g) => g['name'])
                                          .join(', '),
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12),
                                    )
                                  : null,
                            );
                          },
                          onSelected: (suggestion) {
                            setState(() {
                              selectedGame = suggestion;
                              gameController.text =
                                  suggestion['name'] as String? ?? '';
                            });
                          },
                          emptyBuilder: (context) => Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'No matching games found',
                                  style: TextStyle(color: Colors.white54),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'You can still type a custom game name',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Max spots selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Max Players: $maxSpots',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                        Slider(
                          value: maxSpots.toDouble(),
                          min: 2,
                          max: 10,
                          divisions: 8,
                          activeColor: Colors.cyanAccent,
                          inactiveColor: Colors.white24,
                          onChanged: (value) {
                            setState(() {
                              maxSpots = value.toInt();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final squadName = nameController.text.trim();
                    final gameName =
                        selectedGame?['name'] ?? gameController.text.trim();

                    if (squadName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter a squad name')),
                      );
                      return;
                    }

                    if (gameName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please select or enter a game')),
                      );
                      return;
                    }

                    try {
                      final user = AuthServiceSupabase().currentUser;
                      if (user == null) throw 'User not authenticated';

                      final notifier = ref.read(lobbyNotifierProvider.notifier);
                      await notifier.createSquad(squadName, gameName, maxSpots);

                      // Note: createSquad doesn't return the created lobby ID
                      // Set current lobby ID would need to be done after fetching the created lobby

                      HapticFeedback.lightImpact();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Squad created successfully!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to create squad: $e')),
                        );
                      }
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Create',
                    style: TextStyle(color: Colors.cyanAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showJoinSquadDialog(BuildContext context) {
    // TODO: Implement join squad via code dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Join via code not yet implemented'),
      ),
    );
  }

  String _formatLastActivity(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}
