import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../services/auth_service_supabase.dart';
import '../presentation/notifiers/discovery_notifier.dart';
import '../presentation/notifiers/lobby_notifier.dart';
import '../presentation/notifiers/chat_notifier.dart';
import '../presentation/notifiers/game_state_notifier.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../presentation/notifiers/game_notifier.dart';

import '../domain/entities/lobby.dart';
import '../domain/entities/message.dart';
import '../domain/entities/game.dart';
import '../core/app_theme.dart';
import '../chat/chat_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _gameSearchController = TextEditingController();
  String _searchQuery = '';
  String _gameSearchQuery = '';
  Game? _selectedGame;
  List<Game> _favoriteGames = [];
  List<Game> _recentGames = [];
  List<Game> _searchResults = [];
  bool _isLoadingGames = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() => _isLoadingGames = true);

    try {
      // Get favorite games from user preferences
      final userState = ref.read(userNotifierProvider).value;
      if (userState?.pinnedGames != null && userState!.pinnedGames.isNotEmpty) {
        _favoriteGames = userState.pinnedGames
            .map((g) {
              try {
                return Game.fromCache(g);
              } catch (e) {
                debugPrint('Error parsing favorite game: $e');
                return null;
              }
            })
            .where((g) => g != null)
            .cast<Game>()
            .toList();
      }

      // Get game history (recent games)
      final gameState = await ref.read(gameStateNotifierProvider.future);
      _recentGames = gameState.gameHistory
          .take(5)
          .map((g) {
            try {
              return Game.fromCache(g);
            } catch (e) {
              debugPrint('Error parsing recent game: $e');
              return null;
            }
          })
          .where((g) => g != null)
          .cast<Game>()
          .toList();

      if (mounted) setState(() => _isLoadingGames = false);
    } catch (e) {
      debugPrint('Error loading games: $e');
      if (mounted) setState(() => _isLoadingGames = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _gameSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final publicLobbiesAsync = ref.watch(publicLobbiesProvider);

    return Theme(
      data: AppTheme.dark(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Lobbies'),
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: Colors.cyanAccent,
          backgroundColor: Colors.black,
          child: CustomScrollView(
            slivers: [
              // Game Selector Button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildGameSelectorButton(),
                ),
              ),

              // Quick Start Button (shows when game selected)
              if (_selectedGame != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildQuickStartButton(),
                  ),
                ),

              // Available Friends Carousel
              SliverToBoxAdapter(
                child: _buildAvailableFriendsCarousel(),
              ),

              // My Lobbies Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'My Lobbies',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.cyanAccent,
                        ),
                  ),
                ),
              ),
              _buildMyLobbiesSection(),

              // Friends' Lobbies Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Friends\' Lobbies',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.cyanAccent,
                        ),
                  ),
                ),
              ),
              _buildFriendsLobbiesSection(),

              // Explore Public Lobbies Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Explore Public Lobbies',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.cyanAccent,
                        ),
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
                  debugPrint('Supabase error in discovery: $error');

                  // Provide user-friendly error messages
                  String errorMessage = 'Error loading lobbies';
                  if (error.toString().contains('HandshakeException')) {
                    errorMessage = 'Connection issue. Pull to refresh.';
                  } else if (error.toString().contains('timedOut') ||
                      error.toString().contains('RealtimeSubscribeException')) {
                    errorMessage = 'Connection timeout. Pull to refresh.';
                  }

                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off,
                                size: 48, color: Colors.white38),
                            const SizedBox(height: 16),
                            Text(
                              errorMessage,
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ],
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

  Widget _buildGameSelectorButton() {
    final theme = Theme.of(context);

    // If game is selected, show compact view
    if (_selectedGame != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() => _selectedGame = null);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.3),
                theme.colorScheme.primary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              if (_selectedGame!.coverUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _selectedGame!.coverUrl!,
                    width: 48,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.gamepad,
                        size: 48,
                        color: theme.colorScheme.primary),
                  ),
                )
              else
                Icon(Icons.gamepad, size: 48, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedGame!.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Tap to change game',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.close,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      );
    }

    // No game selected - show expanded inline selector
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.2),
            theme.colorScheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.gamepad,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Select Game',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar - Now ABOVE the carousel
          TextField(
            controller: _gameSearchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search all games...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
              suffixIcon: _gameSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _gameSearchController.clear();
                        setState(() {
                          _gameSearchQuery = '';
                          _searchResults = [];
                          _isSearching = false;
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.primary.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            onChanged: (query) async {
              setState(() {
                _gameSearchQuery = query;
                _isSearching = query.isNotEmpty;
              });

              if (query.isEmpty) {
                setState(() => _searchResults = []);
                return;
              }

              // Debounce search
              await Future.delayed(const Duration(milliseconds: 300));
              if (_gameSearchQuery != query) return;

              // Perform IGDB search
              try {
                final result = await ref
                    .read(gameNotifierProvider.notifier)
                    .searchGames(query);

                result.when(
                  data: (games) {
                    if (mounted && _gameSearchQuery == query) {
                      setState(() => _searchResults = games);
                    }
                  },
                  loading: () {},
                  error: (e, st) {
                    debugPrint('Search error: $e');
                    if (mounted) setState(() => _searchResults = []);
                  },
                );
              } catch (e) {
                debugPrint('Search exception: $e');
              }
            },
          ),
          const SizedBox(height: 20),

          // Show search results OR favorite games carousel
          if (_isSearching && _searchResults.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.search, color: theme.colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Search Results',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final game = _searchResults[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildInlineGameCard(game, theme, isLarge: true),
                  );
                },
              ),
            ),
          ] else if (_isSearching) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else ...[
            // Favorite Games Carousel (when NOT searching)
            if (_favoriteGames.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.star, color: theme.colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Favorite Games',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _favoriteGames.length,
                  itemBuilder: (context, index) {
                    final game = _favoriteGames[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildInlineGameCard(game, theme, isLarge: true),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Recent Games Grid
            if (_recentGames.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.history,
                      color: theme.colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Recently Played',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _recentGames
                    .map((game) => _buildInlineGameCard(game, theme))
                    .toList(),
              ),
            ],
          ],

          if (_isLoadingGames)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInlineGameCard(Game game, ThemeData theme,
      {bool isLarge = false}) {
    final width = isLarge ? 120.0 : 80.0;
    final height = isLarge ? 180.0 : 110.0;
    final isFavorite = _favoriteGames
        .any((g) => g.igdbId == game.igdbId || g.name == game.name);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedGame = game);
        ref
            .read(gameStateNotifierProvider.notifier)
            .setCurrentGame(game.toJson());
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Game Cover
              if (game.coverUrl != null)
                Positioned.fill(
                  child: Image.network(
                    game.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: theme.colorScheme.surface.withOpacity(0.5),
                        child: Icon(
                          Icons.gamepad,
                          size: isLarge ? 48 : 32,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  child: Center(
                    child: Icon(
                      Icons.gamepad,
                      size: isLarge ? 48 : 32,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Star button (top right)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    try {
                      final userNotifier =
                          ref.read(userNotifierProvider.notifier);
                      if (isFavorite) {
                        await userNotifier.removePinnedGame(game.name);
                        if (mounted) {
                          setState(() {
                            _favoriteGames.removeWhere((g) =>
                                g.igdbId == game.igdbId || g.name == game.name);
                          });
                        }
                      } else {
                        await userNotifier.addPinnedGame(game.toJson());
                        if (mounted) {
                          setState(() {
                            _favoriteGames.add(game);
                          });
                        }
                      }
                    } catch (e) {
                      debugPrint('Error toggling favorite: $e');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite ? Colors.amber : Colors.white,
                      size: isLarge ? 20 : 16,
                    ),
                  ),
                ),
              ),

              // Game Name
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  game.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isLarge ? 12 : 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStartButton() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton.icon(
        onPressed: _selectedGame == null ? null : _createQuickStartLobby,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.rocket_launch),
        label: Text(
          'Quick Start - ${_selectedGame?.name ?? "Select Game"}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _createQuickStartLobby() async {
    if (_selectedGame == null) return;

    HapticFeedback.mediumImpact();

    try {
      final lobbyNotifier = ref.read(lobbyNotifierProvider.notifier);

      // Smart max spots detection: cached > IGDB data > default 4
      final maxSpots = _selectedGame!.maxSpots ?? 4;

      // Create public lobby
      await lobbyNotifier.createPublicLobby(
        name: '${_selectedGame!.name} - Quick Match',
        gameName: _selectedGame!.name,
        maxSpots: maxSpots,
        description: 'Quick match created via Discovery',
      );

      if (!mounted) return;

      // Show success feedback with navigation action
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Lobby created! ${_selectedGame!.name}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to Lobbies tab (index 1 in bottom navigation)
              DefaultTabController.of(context).animateTo(1);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create lobby: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildAvailableFriendsCarousel() {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAvailableFriends(user.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final availableFriends = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_pin_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Available Friends (${availableFriends.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: availableFriends.length,
                  itemBuilder: (context, index) {
                    final friend = availableFriends[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildAvailableFriendCard(friend),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAvailableFriends(
      String userId) async {
    try {
      // Get user's friends
      final friendsResponse = await SupabaseService.client
          .from('friends')
          .select('friend_uid')
          .eq('user_uid', userId)
          .eq('status', 'accepted');

      final friendUids = (friendsResponse as List)
          .map((f) => f['friend_uid'] as String)
          .toList();

      if (friendUids.isEmpty) {
        return [];
      }

      // Get friends who have available_status set
      final usersResponse = await SupabaseService.client
          .from('users')
          .select(
              'uid, display_name, avatar_url, available_status, available_tags, available_since')
          .inFilter('uid', friendUids)
          .not('available_status', 'is', null)
          .order('available_since', ascending: false);

      return (usersResponse as List).cast<Map<String, dynamic>>();
    } on HandshakeException catch (e) {
      debugPrint(
          '⚠️ Network error fetching available friends (retrying...): $e');
      // Return empty list on network error
      return [];
    } catch (e) {
      debugPrint('Error fetching available friends: $e');
      return [];
    }
  }

  Widget _buildAvailableFriendCard(Map<String, dynamic> friend) {
    final displayName = friend['display_name'] ?? 'Unknown';
    final avatarUrl = friend['avatar_url'];
    final availableTags =
        (friend['available_tags'] as List?)?.cast<String>() ?? [];

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to friend profile or start DM
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$displayName is available!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(displayName[0].toUpperCase())
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (availableTags.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                availableTags.first,
                style: TextStyle(
                  color: Colors.green.shade300,
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMyLobbiesSection() {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text(
              'Sign in to see your lobbies',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return FutureBuilder<List<Lobby>>(
      future: _fetchMyLobbies(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading lobbies: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final myLobbies = snapshot.data ?? [];

        if (myLobbies.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No active lobbies. Create one!',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildLobbyCard(context, myLobbies[index], ref),
            childCount: myLobbies.length,
          ),
        );
      },
    );
  }

  Future<List<Lobby>> _fetchMyLobbies(String userId) async {
    try {
      // Build query with all filters before execution
      var query = SupabaseService.client
          .from('lobbies')
          .select()
          .contains('member_uids', [userId]).eq('is_active', true);

      // Filter by selected game if set
      if (_selectedGame != null) {
        query = query.eq('game_name', _selectedGame!.name);
      }

      // Apply ordering and execute
      final response = await query.order('created_at', ascending: false);

      return (response as List).map((json) => Lobby.fromJson(json)).toList();
    } on HandshakeException catch (e) {
      debugPrint('⚠️ Network error fetching my lobbies (retrying...): $e');
      // Return empty list on network error to avoid crashes
      return [];
    } catch (e) {
      debugPrint('Error fetching my lobbies: $e');
      return [];
    }
  }

  Widget _buildFriendsLobbiesSection() {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return FutureBuilder<List<Lobby>>(
      future: _fetchFriendsLobbies(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading friends\' lobbies: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final friendsLobbies = snapshot.data ?? [];

        if (friendsLobbies.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No friends\' lobbies found',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildLobbyCard(context, friendsLobbies[index], ref),
            childCount: friendsLobbies.length,
          ),
        );
      },
    );
  }

  Future<List<Lobby>> _fetchFriendsLobbies(String userId) async {
    try {
      // First, get user's friends
      final friendsResponse = await SupabaseService.client
          .from('friends')
          .select('friend_uid')
          .eq('user_uid', userId)
          .eq('status', 'accepted');

      final friendUids = (friendsResponse as List)
          .map((f) => f['friend_uid'] as String)
          .toList();

      if (friendUids.isEmpty) {
        return [];
      }

      // Then, get lobbies where any friend is a member
      var query = SupabaseService.client
          .from('lobbies')
          .select()
          .filter('member_uids', 'cs', '{${friendUids.join(',')}}')
          .eq('is_active', true);

      // Filter by selected game if set
      if (_selectedGame != null) {
        query = query.eq('game_name', _selectedGame!.name);
      }

      // Apply ordering/limits and execute
      final response =
          await query.order('created_at', ascending: false).limit(20);

      return response.map((json) => Lobby.fromJson(json)).toList();
    } on HandshakeException catch (e) {
      debugPrint(
          '⚠️ Network error fetching friends\' lobbies (retrying...): $e');
      return [];
    } catch (e) {
      debugPrint('Error fetching friends\' lobbies: $e');
      return [];
    }
  }

  // _buildFilterChip removed - filter chips not currently used in revamped design

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

    // Guard against empty spots array
    if (lobby.spots.isEmpty || lobby.spots.length < maxSpots) {
      return availableSpots;
    }

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
          .select('member_uids, spots, chat_group_id')
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

      // Join the chat group if it exists
      final chatGroupId = lobbyData['chat_group_id'] as String?;
      if (chatGroupId != null) {
        await ref.read(chatNotifierProvider.notifier).joinGroup(chatGroupId);
        // Reload user groups to show the newly joined group
        await ref.read(chatNotifierProvider.notifier).loadUserGroups();
      }

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

        // Navigate to chat if group exists
        if (chatGroupId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ChatScreen(chatType: ChatType.squad),
            ),
          );
        }
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
