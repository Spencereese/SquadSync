import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/notifiers/squad_notifier.dart' as sn;
import '../domain/entities/squad_state.dart';
import '../squad_tab/squad_tab.dart';
import '../utils.dart';
import '../presentation/notifiers/user_notifier.dart';
import 'add_game_screen.dart';

class SquadTabScreen extends StatelessWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const SquadTabScreen(
      {super.key, this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  Widget build(BuildContext context) {
    return _SquadTabScreenContent(
        lobbyId: lobbyId,
        gameName: gameName,
        game: game,
        chatGroupId: chatGroupId);
  }
}

class _SquadTabScreenContent extends ConsumerStatefulWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const _SquadTabScreenContent(
      {this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  ConsumerState<_SquadTabScreenContent> createState() =>
      _SquadTabScreenContentState();
}

class _SquadTabScreenContentState
    extends ConsumerState<_SquadTabScreenContent> {
  late PageController _pageController;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.75);
    _pageController.addListener(() {
      final newPage = _pageController.page ?? 0.0;
      if (newPage.round() != _currentPage.round()) {
        // Haptic feedback on page snap
        HapticFeedback.lightImpact();
      }
      setState(() {
        _currentPage = newPage;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final squadAsync = ref.watch(sn.squadNotifierProvider);
    return squadAsync.when(
      data: (squadState) {
        // If gameName is provided, show full squad management interface
        // (lobbyId is optional - SquadTab can handle showing spots for a game)
        if (widget.gameName != null) {
          return _buildFullSquadInterface(context, squadState);
        }

        // If no squad selected, show squad selection/dashboard instead of welcome screen
        if (squadState.selectedSquadId == null) {
          return _buildDashboardInterface(context, squadState, ref);
        }

        // Otherwise, show the dashboard with active lobbies
        return _buildDashboardInterface(context, squadState, ref);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showErrorSnackBar(context, 'Failed to load squad data: $error');
        });
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $error'),
                ElevatedButton(
                  onPressed: () => ref.invalidate(sn.squadNotifierProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboardInterface(
      BuildContext context, SquadState squadState, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Squad Lobbies'),
        backgroundColor: Colors.black,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.indigo],
          ),
        ),
        child: Column(
          children: [
            // Game Select Title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Game Select',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Pinned Games Carousel
            SizedBox(
              height: 450,
              child: _buildPinnedGamesCarousel(context, ref),
            ),
            // Active Lobbies Section
            Expanded(
              child: _buildActiveLobbiesSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullSquadInterface(BuildContext context, SquadState squadState) {
    // Import and use the original SquadTab widget for full squad management
    return SquadTab(
        lobbyId: widget.lobbyId,
        gameName: widget.gameName,
        game: widget.game,
        chatGroupId: widget.chatGroupId);
  }

  Widget _buildPinnedGamesCarousel(BuildContext context, WidgetRef ref) {
    final userStateAsync = ref.watch(userNotifierProvider);
    final pinnedGames = userStateAsync.maybeWhen(
      data: (userState) => userState?.pinnedGames ?? <Map<String, dynamic>>[],
      orElse: () => <Map<String, dynamic>>[],
    );

    if (pinnedGames.isEmpty) {
      return const Center(
        child: Text(
          'No pinned games',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: pinnedGames.length + 1, // +1 for the add game card
      itemBuilder: (context, index) {
        // Last item is the "Add Game" card
        if (index == pinnedGames.length) {
          return _buildAddGameCard(context, pinnedGames);
        }

        final game = pinnedGames[index];
        final isSelected = index == _currentPage.round();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 450,
          margin: EdgeInsets.symmetric(
            horizontal: 8.0,
            vertical: isSelected ? 0 : 16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: game['coverUrl'] != null
                ? DecorationImage(
                    image: NetworkImage(game['coverUrl']),
                    fit: BoxFit.cover,
                  )
                : null,
            color: game['coverUrl'] == null ? Colors.grey[800] : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectGame(context, game),
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Game name overlay at the bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        game['name'] ?? 'Unknown Game',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddGameCard(
      BuildContext context, List<Map<String, dynamic>> pinnedGames) {
    final isSelected = pinnedGames.length == _currentPage.round();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: isSelected ? 0 : 16,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[800],
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addGame(context),
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  size: 48,
                  color: Colors.cyanAccent,
                ),
                SizedBox(height: 8),
                Text(
                  'Add Game',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addGame(BuildContext context) {
    // Navigate to add game screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddGameScreen(),
      ),
    );
  }

  void _selectGame(BuildContext context, Map<String, dynamic> game) {
    // Navigate to the full squad interface for this game
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SquadTabScreen(
          gameName: game['name'],
          game: game,
        ),
      ),
    );
  }

  void _handleQuickJoin(BuildContext context, WidgetRef ref) async {
    final userStateAsync = ref.watch(userNotifierProvider);
    final pinnedGames = userStateAsync.maybeWhen(
      data: (userState) => userState?.pinnedGames ?? <Map<String, dynamic>>[],
      orElse: () => <Map<String, dynamic>>[],
    );

    if (pinnedGames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pinned games to quick join')),
      );
      return;
    }

    // For now, just select the first pinned game
    // TODO: Implement proper quick join logic with lobby suggestions
    _selectGame(context, pinnedGames.first);
  }

  Widget _buildActiveLobbiesSection(BuildContext context) {
    final squadAsync = ref.watch(sn.squadNotifierProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return squadAsync.when(
      data: (squadState) {
        final activeLobbies = squadState.gameLobbies.entries
            .expand((entry) => entry.value)
            .where((lobby) {
          final maxSpots = lobby['spots'] ?? 4;
          final filled = (lobby['filled'] as List<dynamic>?)?.length ?? 0;
          final timer = lobby['timer'];
          final isActive = timer != null &&
              (timer is DateTime
                  ? timer.isAfter(DateTime.now())
                  : timer.toDate().isAfter(DateTime.now()));

          return filled < maxSpots && isActive;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Play Button - Centered
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton.icon(
                  onPressed: () => _handleQuickJoin(context, ref),
                  icon: const Icon(Icons.electric_bolt, color: Colors.white),
                  label: const Text(
                    'Quick Play',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Active Lobbies',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Trigger a refresh of squad state
                  ref.invalidate(sn.squadNotifierProvider);
                },
                child: activeLobbies.isEmpty
                    ? const Center(
                        child: Text(
                          'No active lobbies',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        itemCount: activeLobbies.length,
                        itemBuilder: (context, index) {
                          final lobby = activeLobbies[index];
                          return ListTile(
                            title: Text(
                              lobby['gameName'] ?? 'Unknown Game',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${lobby['filled']?.length ?? 0}/${lobby['spots'] ?? 4} players',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            onTap: () => _joinLobby(context, lobby),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading lobbies: $error',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _joinLobby(BuildContext context, Map<String, dynamic> lobby) {
    // Navigate to the squad tab for this lobby
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SquadTabScreen(
          lobbyId: lobby['id'],
          gameName: lobby['gameName'],
        ),
      ),
    );
  }
}
