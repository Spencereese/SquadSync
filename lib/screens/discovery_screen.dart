import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../services/auth_service_supabase.dart';
import '../presentation/notifiers/discovery_notifier.dart';
import '../presentation/notifiers/lobby_notifier.dart';
import '../domain/entities/lobby.dart';
import '../domain/entities/message.dart';
import '../core/app_theme.dart';
import '../chat/chat_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(discoveryFilterProvider);
    final popularGamesAsync = ref.watch(popularGamesProvider);
    final publicLobbiesAsync = ref.watch(publicLobbiesProvider);

    return Theme(
      data: AppTheme.dark(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Discover Lobbies'),
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: Colors.cyanAccent,
          backgroundColor: Colors.black,
          child: CustomScrollView(
            slivers: [
              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search lobbies...',
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: const TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
              ),

              // Filter chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFilterChip('Hot', 'hot', filter == 'hot'),
                      _buildFilterChip('New', 'new', filter == 'new'),
                      const SizedBox(width: 8),
                      ...popularGamesAsync.maybeWhen(
                        data: (games) => games.take(5).map(
                              (game) => _buildFilterChip(
                                  game['gameId'] as String,
                                  game['gameId'] as String,
                                  filter == game['gameId']),
                            ),
                        orElse: () => [],
                      ),
                    ],
                  ),
                ),
              ),

              // Lobbies list
              publicLobbiesAsync.when(
                data: (lobbys) {
                  // Apply search filter
                  final filteredLobbies = _searchQuery.isEmpty
                      ? lobbys
                      : lobbys.where((lobby) {
                          return lobby.name
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              lobby.gameName
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              (lobby.description
                                      ?.toLowerCase()
                                      .contains(_searchQuery) ??
                                  false);
                        }).toList();

                  if (filteredLobbies.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No public lobbies found.\nCreate one to get started!'
                                : 'No lobbies match "$_searchQuery"',
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildLobbyCard(context, filteredLobbies[index], ref),
                      childCount: filteredLobbies.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child:
                          CircularProgressIndicator(color: Colors.cyanAccent),
                    ),
                  ),
                ),
                error: (error, stack) {
                  debugPrint('Firestore error in discovery: $error');
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'Error loading lobbies: $error',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreatePublicLobbyDialog(context, ref),
          backgroundColor: Colors.cyanAccent,
          icon: const Icon(Icons.add, color: Colors.black),
          label: const Text(
            'Create Public Lobby',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            ref.read(discoveryFilterProvider.notifier).state = value;
          }
        },
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
        checkmarkColor: Colors.cyanAccent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.cyanAccent : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildLobbyCard(BuildContext context, Lobby lobby, WidgetRef ref) {
    final availableSpots = _getAvailableSpots(lobby);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lobby name and LFM badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    lobby.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (lobby.isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: const Text(
                      'LFM',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Game chip and spots
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    lobby.gameName,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${lobby.memberUids.length}/${lobby.maxSpots}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                if (availableSpots.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Spots: ${availableSpots.join(", ")}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            const SizedBox(height: 8),

            // Member avatars
            Row(
              children: [
                ...lobby.memberUids.take(5).map((uid) => Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.cyanAccent,
                      ),
                    )),
                if (lobby.memberUids.length > 5)
                  Text(
                    '+${lobby.memberUids.length - 5}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              lobby.description ?? 'No description',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Join button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => _joinLobby(context, lobby, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Join'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getAvailableSpots(Lobby lobby) {
    final availableSpots = <String>[];
    final maxSpots = lobby.maxSpots;
    for (int i = 1; i <= maxSpots; i++) {
      if (lobby.spots[i - 1] == null) {
        availableSpots.add(i.toString());
      }
    }
    return availableSpots;
  }

  Future<void> _onRefresh() async {
    // Refresh discovery data
    ref.invalidate(publicLobbiesProvider);

    // Refresh the data
    await Future.delayed(const Duration(seconds: 1));
  }

  void _joinLobby(BuildContext context, Lobby lobby, WidgetRef ref) async {
    try {
      final uid = AuthServiceSupabase().currentUser!.id;

      // Get current lobby data
      final lobbyData = await SupabaseService.client
          .from('lobbies')
          .select('member_uids, spots')
          .eq('id', lobby.id)
          .maybeSingle();

      if (lobbyData == null) return;

      // Add user to member_uids
      final memberUids = List<String>.from(lobbyData['member_uids'] ?? []);
      if (!memberUids.contains(uid)) {
        memberUids.add(uid);
      }

      // Auto-claim first available spot
      final spots = List<String?>.from(lobbyData['spots'] ?? []);
      final maxSpots = lobby.maxSpots;
      for (int i = 0; i < maxSpots && i < spots.length; i++) {
        if (spots[i] == null) {
          spots[i] = uid;
          break; // Only claim the first available spot
        }
      }

      await SupabaseService.client.from('lobbies').update({
        'member_uids': memberUids,
        'spots': spots,
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('id', lobby.id);

      // Set as current lobby
      ref.read(lobbyNotifierProvider.notifier).setSelectedLobbyId(lobby.id);

      // Show success toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${lobby.name}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to chat
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ChatScreen(chatType: ChatType.squad),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join lobby: $e')),
        );
      }
    }
  }

  void _showCreatePublicLobbyDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedGame = 'Call of Duty';
    int maxSpots = 4;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Create Public Lobby',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lobby Name
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Lobby Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'e.g. Chill Ranked Matches',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Game Selection
                DropdownButtonFormField<String>(
                  value: selectedGame,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Game',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    'Call of Duty',
                    'Fortnite',
                    'Apex Legends',
                    'Valorant',
                    'League of Legends',
                    'Rocket League',
                    'Destiny 2',
                    'Overwatch 2',
                  ].map((game) {
                    return DropdownMenuItem(
                      value: game,
                      child: Text(game),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedGame = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Max Spots
                DropdownButtonFormField<int>(
                  value: maxSpots,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Max Players',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [2, 3, 4, 5, 6, 8, 10].map((spots) {
                    return DropdownMenuItem(
                      value: spots,
                      child: Text('$spots players'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        maxSpots = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText:
                        'Tell others what kind of players you\'re looking for',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final lobbyName = nameController.text.trim();
                if (lobbyName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a lobby name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Create the public lobby
                  final lobbyNotifier =
                      ref.read(lobbyNotifierProvider.notifier);
                  await lobbyNotifier.createPublicLobby(
                    name: lobbyName,
                    gameName: selectedGame,
                    maxSpots: maxSpots,
                    description: descriptionController.text.trim(),
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Public lobby created!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create lobby: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
