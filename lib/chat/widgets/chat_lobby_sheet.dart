import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_theme.dart';
import '../../core/notification_routes.dart';
import '../../domain/entities/lobby.dart';
import '../../domain/entities/lobby_state.dart';
import '../../domain/entities/game.dart';
import '../../presentation/notifiers/lobby_notifier.dart';
import '../../presentation/notifiers/user_notifier.dart';
import '../../presentation/notifiers/game_notifier.dart';
import '../../screens/lobby_tab_screen.dart';

/// Chat lobby sheet showing pinned games carousel and active lobbies for the group
class ChatLobbySheet extends ConsumerStatefulWidget {
  final String chatGroupId;
  final String chatGroupName;

  const ChatLobbySheet({
    super.key,
    required this.chatGroupId,
    required this.chatGroupName,
  });

  static Future<void> show(
    BuildContext context, {
    required String chatGroupId,
    required String chatGroupName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatLobbySheet(
        chatGroupId: chatGroupId,
        chatGroupName: chatGroupName,
      ),
    );
  }

  @override
  ConsumerState<ChatLobbySheet> createState() => _ChatLobbySheetState();
}

class _ChatLobbySheetState extends ConsumerState<ChatLobbySheet> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  double _currentPage = 0;
  Timer? _debounce;
  List<Game> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingSearch = false;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0;
      });
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _isLoadingSearch = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoadingSearch = true;
    });

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final result =
          await ref.read(gameNotifierProvider.notifier).searchGames(query);

      result.when(
        data: (games) {
          if (mounted && _searchController.text.trim() == query) {
            setState(() {
              _searchResults = games;
              _isLoadingSearch = false;
            });
          }
        },
        loading: () {},
        error: (e, st) {
          debugPrint('Search error: $e');
          if (mounted) {
            setState(() {
              _searchResults = [];
              _isLoadingSearch = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoadingSearch = false;
        });
      }
    }
  }

  Future<void> _createLobby(Map<String, dynamic> game) async {
    try {
      final lobbyId =
          await ref.read(lobbyNotifierProvider.notifier).createLobby(
                chatGroupId: widget.chatGroupId,
                chatGroupName: widget.chatGroupName,
                gameName: game['name']?.toString() ?? '',
                maxSpots: 8, // Default max spots
                isPublic: false,
              );

      if (mounted) {
        HapticFeedback.mediumImpact();
        _landOnSquadLobby(
          lobbyId,
          gameName: game['name']?.toString(),
          game: game,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create lobby: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Friends and creator land on THIS lobby: `/squad?lobby_id=`.
  void _landOnSquadLobby(
    String lobbyId, {
    String? gameName,
    Map<String, dynamic>? game,
  }) {
    final location = '/squad?lobby_id=${Uri.encodeComponent(lobbyId)}';
    final go = NotificationRoutes.go;
    GoRouter? router;
    try {
      router = GoRouter.of(context);
    } catch (_) {}
    Navigator.of(context).pop();
    if (go != null) {
      go(location);
      return;
    }
    if (router != null) {
      router.go(location);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LobbyTabScreen(
          lobbyId: lobbyId,
          gameName: gameName,
          game: game,
          chatGroupId: widget.chatGroupId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neonColor = Colors.white;
    final userStateAsync = ref.watch(userNotifierProvider);
    final lobbyState = ref.watch(lobbyNotifierProvider);

    final pinnedGames = userStateAsync.maybeWhen(
      data: (userState) => userState?.pinnedGames ?? <Map<String, dynamic>>[],
      orElse: () => <Map<String, dynamic>>[],
    );

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {}, // Prevent dismissal when tapping content
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return GlassmorphicContainer(
                neonColor: neonColor,
                blur: 30,
                borderRadius: 24,
                child: Column(
                  children: [
                    // Drag handle with neon glow
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: neonColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: neonColor.neonGlow(
                          blur: 10,
                          opacity: 0.3,
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lobby',
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: neonColor,
                                    shadows: neonColor.neonGlow(
                                      blur: 10,
                                      opacity: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Select a pinned game',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Close button
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                            icon: Icon(
                              Icons.close,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.surface.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: neonColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search for a game...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: neonColor,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchFocusNode.unfocus();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: neonColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: neonColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: neonColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Games Carousel (Pinned or Search Results)
                    if (_isSearching) ...[
                      // Search Results Section
                      if (_isLoadingSearch)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        )
                      else if (_searchResults.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No games found for "${_searchController.text}"',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                          child: Text(
                            'Search Results',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: neonColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 400,
                          child: _buildSearchResultsCarousel(neonColor),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ] else if (pinnedGames.isNotEmpty) ...[
                      // Pinned Games Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Text(
                          'Pinned Games',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: neonColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 400,
                        child:
                            _buildPinnedGamesCarousel(pinnedGames, neonColor),
                      ),
                      const SizedBox(height: 24),
                    ] else
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No pinned games. Pin games in your profile!',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Active Lobbies Section
                    Expanded(
                      child: _buildActiveLobbiesSection(
                        lobbyState,
                        scrollController,
                        theme,
                        neonColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsCarousel(Color neonColor) {
    return PageView.builder(
      controller: _pageController,
      clipBehavior: Clip.none,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final game = _searchResults[index];
        final isSelected = index == _currentPage.round();
        final gameMap = game.toJson();

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
            onTap: () {
              HapticFeedback.mediumImpact();
              _createLobby(gameMap);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Background image
                  if (game.coverUrl != null && game.coverUrl!.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        game.coverUrl!.startsWith('http')
                            ? game.coverUrl!
                            : 'https:${game.coverUrl}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF14181F),
                        ),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: Container(color: const Color(0xFF14181F)),
                    ),

                  // Glass border
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
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
                            game.name,
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

  Widget _buildPinnedGamesCarousel(
    List<Map<String, dynamic>> pinnedGames,
    Color neonColor,
  ) {
    return PageView.builder(
      controller: _pageController,
      clipBehavior: Clip.none,
      itemCount: pinnedGames.length,
      itemBuilder: (context, index) {
        final game = pinnedGames[index];
        final isSelected = index == _currentPage.round();

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
            onTap: () {
              HapticFeedback.mediumImpact();
              _createLobby(game);
            },
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
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF14181F),
                        ),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: Container(color: const Color(0xFF14181F)),
                    ),

                  // Glass border
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
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

  Widget _buildActiveLobbiesSection(
    AsyncValue<LobbyState> lobbyStateAsync,
    ScrollController scrollController,
    ThemeData theme,
    Color neonColor,
  ) {
    return lobbyStateAsync.when(
      data: (lobbyState) {
        // Get active lobbies for this chat group
        final activeLobbies = <Map<String, dynamic>>[];
        final seenIds = <String>{};

        void addBoundLobby(Map<String, dynamic> lobby) {
          final id = lobby['id']?.toString();
          if (id != null && id.isNotEmpty && !seenIds.add(id)) return;
          activeLobbies.add(lobby);
        }

        Map<String, dynamic> lobbyEntityToMap(Lobby lobby) => {
              'id': lobby.id,
              'name': lobby.name,
              'gameName': lobby.gameName,
              'spots': lobby.spots,
              'maxSpots': lobby.maxSpots,
              'chatGroupId': lobby.chatGroupId,
              'isActive': lobby.isActive,
            };

        for (final lobby in lobbyState.userLobbies.values) {
          if (lobby.chatGroupId == widget.chatGroupId && lobby.isActive) {
            addBoundLobby(lobbyEntityToMap(lobby));
          }
        }
        final current = lobbyState.currentLobby;
        if (current != null &&
            current.chatGroupId == widget.chatGroupId &&
            current.isActive) {
          addBoundLobby(lobbyEntityToMap(current));
        }

        // Check for private lobbies in this chat group
        lobbyState.gameLobbies.forEach((gameName, lobbies) {
          for (final lobby in lobbies) {
            if (lobby['chatGroupId'] == widget.chatGroupId &&
                lobby['isActive'] == true) {
              addBoundLobby(lobby);
            }
          }
        });

        // Check if any group members are in public lobbies
        final memberPublicLobbies = <Map<String, dynamic>>[];
        lobbyState.gameLobbies.forEach((gameName, lobbies) {
          for (final lobby in lobbies) {
            if (lobby['isActive'] == true) {
              // Check if any member UIDs are in this lobby's spots
              final spots = lobby['spots'] as List<String?>? ?? [];
              final hasGroupMember = spots.any((uid) =>
                  uid != null && lobbyState.lobbyMemberUids.contains(uid));
              if (hasGroupMember) {
                memberPublicLobbies.add({...lobby, 'isPublic': true});
              }
            }
          }
        });

        final allLobbies = [...activeLobbies, ...memberPublicLobbies];

        if (allLobbies.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active lobbies',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a lobby to get started!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.gamepad, size: 20, color: neonColor),
                  const SizedBox(width: 8),
                  Text(
                    'Active Lobbies',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: neonColor,
                      shadows: neonColor.neonGlow(blur: 8, opacity: 0.3),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: neonColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: neonColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${allLobbies.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: neonColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: allLobbies.length,
                itemBuilder: (context, index) {
                  final lobby = allLobbies[index];
                  final isPublic = lobby['isPublic'] == true;
                  return _buildLobbyCard(lobby, theme, neonColor, isPublic);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading lobbies',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
    );
  }

  Widget _buildLobbyCard(
    Map<String, dynamic> lobby,
    ThemeData theme,
    Color neonColor,
    bool isPublic,
  ) {
    final gameName = lobby['gameName'] ?? 'Unknown Game';
    final spots = lobby['spots'] as List<String?>? ?? [];
    final filledSpots = spots.where((s) => s != null).length;
    final maxSpots = lobby['maxSpots'] ?? spots.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: neonColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            final lobbyId = lobby['id']?.toString();
            if (lobbyId != null && lobbyId.isNotEmpty) {
              _landOnSquadLobby(lobbyId, gameName: gameName);
              return;
            }
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LobbyTabScreen(
                  gameName: gameName,
                  chatGroupId: widget.chatGroupId,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Game icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: neonColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: neonColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.gamepad,
                    color: neonColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Lobby info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              gameName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPublic)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.secondary
                                      .withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'PUBLIC',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$filledSpots/$maxSpots spots filled',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
