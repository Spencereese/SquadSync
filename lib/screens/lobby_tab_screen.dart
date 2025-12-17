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
import '../widgets/unified_game_selection_sheet.dart';
import '../core/app_theme.dart';
import 'discovery_screen.dart';

class LobbyTabScreen extends StatelessWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const LobbyTabScreen(
      {super.key, this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  Widget build(BuildContext context) {
    return _LobbyTabScreenContent(
        lobbyId: lobbyId,
        gameName: gameName,
        game: game,
        chatGroupId: chatGroupId);
  }
}

class _LobbyTabScreenContent extends ConsumerStatefulWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const _LobbyTabScreenContent(
      {this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  ConsumerState<_LobbyTabScreenContent> createState() =>
      _LobbyTabScreenContentState();
}

class _LobbyTabScreenContentState
    extends ConsumerState<_LobbyTabScreenContent> {
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
        // (lobbyId is optional - LobbyTab can handle showing spots for a game)
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
    // Use the revamped Discovery screen as the Lobby tab content
    return const DiscoveryScreen();
  }

  Widget _buildFullSquadInterface(BuildContext context, LobbyState squadState) {
    // Import and use the original LobbyTab widget for full squad management
    return LobbyTab(
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
      clipBehavior: Clip.none,
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
          clipBehavior: Clip.none,
          margin: EdgeInsets.symmetric(
            horizontal: 8.0,
            vertical: isSelected ? 0 : 16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? neonColor.neonGlow(
                    blur: 25,
                    spread: 2,
                    opacity: 0.4,
                  )
                : null,
          ),
          child: GestureDetector(
            onTap: () => _selectGame(context, game),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
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
                        color: null,
                        colorBlendMode: null,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF14181F),
                        ),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: Container(color: const Color(0xFF14181F)),
                    ),

                  // Glass border (no shadow)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                neonColor.withOpacity(isSelected ? 0.6 : 0.3),
                            width: isSelected ? 2.5 : 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

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

  void _addGame(BuildContext context) async {
    // Use unified game selection sheet for consistency
    await UnifiedGameSelectionSheet.show(
      context,
      title: 'Add Game to Pinned',
      subtitle: 'Choose a game to add to your pinned games',
      showPinnedGames: false, // Don't show pinned games when adding
      showSearchButton: true,
      showMaxSpotSelector: false,
      onGameSelected: (game) async {
        try {
          final userNotifier = ref.read(userNotifierProvider.notifier);
          await userNotifier.addPinnedGame(game.toJson());

          if (mounted) {
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${game.name} added to pinned games!'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to add game: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      },
    );
  }

  void _selectGame(BuildContext context, Map<String, dynamic> game) {
    // Navigate to the full squad interface for this game
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LobbyTabScreen(
          gameName: game['name'],
          game: game,
        ),
      ),
    );
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
        builder: (context) => LobbyTabScreen(
          lobbyId: lobby['id'],
          gameName: lobby['gameName'],
        ),
      ),
    );
  }
}
