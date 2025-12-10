import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service_supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../domain/entities/lobby_state.dart';
import '../lobbies_tab/lobbies_tab.dart';
import '../utils.dart';
import '../presentation/notifiers/user_notifier.dart';
import 'add_game_screen.dart';
import '../core/app_theme.dart';

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
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);
    return squadAsync.when(
      data: (squadState) {
        // If gameName is provided, show full squad management interface
        // (lobbyId is optional - SquadTab can handle showing spots for a game)
        if (widget.gameName != null) {
          return _buildFullSquadInterface(context, squadState);
        }

        // If no squad selected, show squad selection/dashboard instead of welcome screen
        if (squadState.selectedLobbyId == null) {
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
                  onPressed: () => ref.invalidate(ln.lobbyNotifierProvider),
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
      BuildContext context, LobbyState squadState, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Squad Lobbies',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0B0E14),
              const Color(0xFF14181F),
            ],
          ),
        ),
        child: Column(
          children: [
            // Top padding to account for AppBar
            const SizedBox(height: 100),
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

  Widget _buildFullSquadInterface(BuildContext context, LobbyState squadState) {
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
        final theme = Theme.of(context);
        final neonColor = theme.colorScheme.primary;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 450,
          margin: EdgeInsets.symmetric(
            horizontal: 8.0,
            vertical: isSelected ? 0 : 16,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Background image
                if (game['coverUrl'] != null)
                  Positioned.fill(
                    child: Image.network(
                      game['coverUrl'].toString().startsWith('http')
                          ? game['coverUrl']
                          : 'https:${game['coverUrl']}',
                      fit: BoxFit.cover,
                      colorBlendMode: BlendMode.dst,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF14181F),
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(color: const Color(0xFF14181F)),
                  ),

                // Glass border with neon glow
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: neonColor.withOpacity(isSelected ? 0.6 : 0.3),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? neonColor.neonGlow(
                              blur: 25,
                              spread: 2,
                              opacity: 0.4,
                            )
                          : null,
                    ),
                  ),
                ),

                // Content
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _selectGame(context, game),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Game name overlay at the bottom
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  border: Border(
                                    top: BorderSide(
                                      color: neonColor.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  game['name'] ?? 'Unknown Game',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    shadows: neonColor.neonGlow(
                                      blur: 10,
                                      opacity: 0.3,
                                    ),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddGameCard(
      BuildContext context, List<Map<String, dynamic>> pinnedGames) {
    final isSelected = pinnedGames.length == _currentPage.round();
    final theme = Theme.of(context);
    final neonColor = theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: isSelected ? 0 : 16,
      ),
      child: GlassmorphicContainer(
        neonColor: neonColor,
        blur: 20,
        borderRadius: 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _addGame(context),
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: neonColor.withOpacity(0.1),
                      border: Border.all(
                        color: neonColor.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: neonColor.neonGlow(
                        blur: 20,
                        opacity: 0.3,
                      ),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 48,
                      color: neonColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add Game',
                    style: TextStyle(
                      color: neonColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: neonColor.neonGlow(
                        blur: 10,
                        opacity: 0.3,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);
    final user = AuthServiceSupabase().currentUser;
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
                  ref.invalidate(ln.lobbyNotifierProvider);
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
