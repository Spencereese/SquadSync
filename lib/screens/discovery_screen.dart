import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../services/auth_service_supabase.dart';
import '../presentation/notifiers/discovery_notifier.dart';
import '../presentation/notifiers/current_squad_notifier.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(discoveryFilterProvider);
    final popularGamesAsync = ref.watch(popularGamesProvider);
    final publicSquadsAsync = ref.watch(publicSquadsProvider);

    return Theme(
      data: AppTheme.dark(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Discover Squads'),
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
                      hintText: 'Search squads...',
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
                      // TODO: Implement search filtering
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

              // Squads list
              publicSquadsAsync.when(
                data: (squads) => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildSquadCard(context, squads[index], ref),
                    childCount: squads.length,
                  ),
                ),
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
                  print('Firestore error in discovery: $error');
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'Error loading squads: $error',
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
          onPressed: () => _showCreatePublicSquadDialog(context, ref),
          backgroundColor: Colors.cyanAccent,
          icon: const Icon(Icons.add, color: Colors.black),
          label: const Text(
            'Create Public Squad',
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

  Widget _buildSquadCard(BuildContext context, Squad squad, WidgetRef ref) {
    final availableSpots = _getAvailableSpots(squad);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Squad name and LFM badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    squad.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (squad.isActive)
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
                    squad.gameName,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${squad.memberUids.length}/${squad.maxSpots}',
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
                ...squad.memberUids.take(5).map((uid) => Container(
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
                if (squad.memberUids.length > 5)
                  Text(
                    '+${squad.memberUids.length - 5}',
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
              squad.description ?? 'No description',
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
                onPressed: () => _joinSquad(context, squad, ref),
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
    final maxSpots = squad.maxSpots;
    for (int i = 1; i <= maxSpots; i++) {
      if (squad.spots[i - 1] == null) {
        availableSpots.add(i.toString());
      }
    }
    return availableSpots;
  }

  Future<void> _onRefresh() async {
    // Bump current squad if it's public
    final currentSquadAsync = ref.read(currentLobbyProvider);
    currentSquadAsync.maybeWhen(
      data: (squad) {
        if (squad?.isPublic == true) {
          ref.read(currentLobbyProvider.notifier).bumpSquad().catchError((_) {
            // Ignore bump errors during refresh
          });
        }
      },
      orElse: () {},
    );

    // Refresh the data
    await Future.delayed(const Duration(seconds: 1));
  }

  void _joinSquad(BuildContext context, Squad squad, WidgetRef ref) async {
    try {
      final uid = AuthServiceSupabase().currentUser!.id;

      // Get current squad data
      final squadData = await SupabaseService.client
          .from('squads')
          .select('member_uids, spots')
          .eq('id', squad.id)
          .maybeSingle();

      if (squadData == null) return;

      // Add user to member_uids
      final memberUids = List<String>.from(squadData['member_uids'] ?? []);
      if (!memberUids.contains(uid)) {
        memberUids.add(uid);
      }

      // Auto-claim first available spot
      final spots = List<String?>.from(squadData['spots'] ?? []);
      final maxSpots = squad.maxSpots;
      for (int i = 0; i < maxSpots && i < spots.length; i++) {
        if (spots[i] == null) {
          spots[i] = uid;
          break; // Only claim the first available spot
        }
      }

      await SupabaseService.client.from('squads').update({
        'member_uids': memberUids,
        'spots': spots,
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('id', squad.id);

      // Set as current squad
      ref.read(currentLobbyIdProvider.notifier).state = squad.id;

      // Show success toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${squad.name}!'),
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
          SnackBar(content: Text('Failed to join squad: $e')),
        );
      }
    }
  }

  void _showCreatePublicSquadDialog(BuildContext context, WidgetRef ref) {
    // TODO: Implement create public squad dialog with pre-filled defaults
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Create Public Squad',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Public squad creation coming soon!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
