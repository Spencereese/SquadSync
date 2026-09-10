import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/injection.dart';
import '../../domain/entities/game.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../presentation/notifiers/user_notifier.dart';
import '../../presentation/notifiers/game_notifier.dart';
import '../../widgets/game_tile.dart';
import '../../widgets/unified_game_selection_sheet.dart';
import '../../core/app_theme.dart';

/// Full-screen lobby creation with chat info screen styling
/// Matches glassmorphic theme with animated slide-up transition
class FullScreenLobbyCreation extends ConsumerStatefulWidget {
  final String chatGroupId;

  const FullScreenLobbyCreation({
    super.key,
    required this.chatGroupId,
  });

  @override
  ConsumerState<FullScreenLobbyCreation> createState() =>
      _FullScreenLobbyCreationState();
}

class _FullScreenLobbyCreationState
    extends ConsumerState<FullScreenLobbyCreation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Form state
  Game? _selectedGame;
  final List<String> _selectedTags = [];
  String _visibility = 'group_private';
  bool _isLoading = false;
  int _maxSpots = 4;

  // Trending tags
  List<String> _trendingTags = [];

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  List<Game> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingSearch = false;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // Start animation
    _animationController.forward();

    // Load trending tags
    _loadTrendingTags();

    // Setup search listener
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
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

  Future<void> _loadTrendingTags() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('tag_analytics')
          .select('tag, trending_score')
          .gt('trending_score', 5.0)
          .order('trending_score', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _trendingTags =
              (response as List).map((tag) => tag['tag'] as String).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading trending tags: $e');
    }
  }

  Future<void> _dismiss() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _createLobby() async {
    if (_selectedGame == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a game')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final lobbyNotifier = ref.read(ln.lobbyNotifierProvider.notifier);

      await lobbyNotifier.createLobbyWithConstitution(
        chatGroupId: widget.chatGroupId,
        gameName: _selectedGame!.name,
        maxSpots: _maxSpots,
        tags: _selectedTags,
        visibility: _visibility,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lobby created!')),
        );
        await _dismiss();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neonColor = theme.colorScheme.primary;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Full-screen blur for liquid glass effect (matching chat info)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          ),

          // Main content
          SlideTransition(
            position: _slideAnimation,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _dismiss,
                ),
                title: Text(
                  'Create Lobby',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                centerTitle: true,
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Game Selection
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Select Game', Icons.gamepad),
                          const SizedBox(height: 12),
                          _buildGameSelector(theme, neonColor),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tags
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Tags', Icons.label),
                          const SizedBox(height: 12),
                          _buildTagsSection(theme, neonColor),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Visibility
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Visibility', Icons.visibility),
                          const SizedBox(height: 12),
                          _buildVisibilitySection(theme, neonColor),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Max Spots
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Max Players', Icons.people),
                          const SizedBox(height: 12),
                          _buildMaxSpotsSlider(theme, neonColor),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Create Button
                    _buildCreateButton(theme, neonColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildGameSelector(ThemeData theme, Color neonColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected game display
        if (_selectedGame != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  neonColor.withOpacity(0.2),
                  neonColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: neonColor.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: _selectedGame!.coverUrl != null &&
                          _selectedGame!.coverUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _selectedGame!.coverUrl!,
                            fit: BoxFit.cover,
                            width: 48,
                            height: 48,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.gamepad,
                                  color: neonColor, size: 28);
                            },
                          ),
                        )
                      : Icon(Icons.gamepad, color: neonColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedGame!.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Selected Game',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedGame = null);
                  },
                ),
              ],
            ),
          ),

        // Search Bar (hidden when game is selected)
        if (_selectedGame == null)
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search for a game...',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: neonColor,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.white.withOpacity(0.7),
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
        if (_selectedGame == null) const SizedBox(height: 16),

        // Games Section (Search Results or Pinned Games) - hidden when game is selected
        if (_selectedGame == null && _isSearching)
          // Search Results
          _isLoadingSearch
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              : _searchResults.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No games found for "${_searchController.text}"',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search Results',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final game = _searchResults[index];
                              final isSelected =
                                  _selectedGame?.name == game.name;
                              return Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _selectedGame = game);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? neonColor
                                            : Colors.white.withOpacity(0.2),
                                        width: isSelected ? 3 : 1,
                                      ),
                                      color: isSelected
                                          ? neonColor.withOpacity(0.2)
                                          : Colors.white.withOpacity(0.05),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (game.coverUrl != null &&
                                            game.coverUrl!.isNotEmpty)
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                game.coverUrl!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Icon(
                                                    Icons.gamepad,
                                                    color: Colors.white
                                                        .withOpacity(0.7),
                                                    size: 36,
                                                  );
                                                },
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                      strokeWidth: 2,
                                                      color: neonColor,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          )
                                        else
                                          Icon(
                                            Icons.gamepad,
                                            color: isSelected
                                                ? neonColor
                                                : Colors.white.withOpacity(0.7),
                                            size: 36,
                                          ),
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: Text(
                                            game.name,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        if (_selectedGame == null && !_isSearching)
          // Pinned games carousel
          Consumer(
            builder: (context, ref, child) {
              final userState = ref.watch(userNotifierProvider);
              return userState.when(
                data: (appUser) {
                  final pinnedGames = appUser?.pinnedGames ?? [];
                  if (pinnedGames.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No pinned games. Search above or pin games in your profile!',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Pinned Games',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: pinnedGames.length,
                          itemBuilder: (context, index) {
                            final gameMap = pinnedGames[index];
                            final gameName =
                                gameMap['name'] as String? ?? 'Unknown';
                            final isSelected = _selectedGame?.name == gameName;
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  // Convert map to Game object
                                  final game = Game.fromJson(gameMap);
                                  setState(() => _selectedGame = game);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? neonColor
                                          : Colors.white.withOpacity(0.2),
                                      width: isSelected ? 3 : 1,
                                    ),
                                    color: isSelected
                                        ? neonColor.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.05),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (gameMap['coverUrl'] != null &&
                                          (gameMap['coverUrl'] as String)
                                              .isNotEmpty)
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                              gameMap['coverUrl'] as String,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.gamepad,
                                                  color: Colors.white
                                                      .withOpacity(0.7),
                                                  size: 36,
                                                );
                                              },
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    value: loadingProgress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? loadingProgress
                                                                .cumulativeBytesLoaded /
                                                            loadingProgress
                                                                .expectedTotalBytes!
                                                        : null,
                                                    strokeWidth: 2,
                                                    color: neonColor,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        )
                                      else
                                        Icon(
                                          Icons.gamepad,
                                          color: isSelected
                                              ? neonColor
                                              : Colors.white.withOpacity(0.7),
                                          size: 36,
                                        ),
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Text(
                                          gameName,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Error loading pinned games',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSearchButton(ThemeData theme, Color neonColor) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await UnifiedGameSelectionSheet.show(
          context,
          title: 'Select Game',
          subtitle: 'Choose a game for this lobby',
          showPinnedGames: true,
          showSearchButton: true,
          showMaxSpotSelector: false,
          onGameSelected: (game) {
            setState(() => _selectedGame = game);
            Navigator.of(context).pop();
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, color: neonColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Search for a game',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection(ThemeData theme, Color neonColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected tags
        if (_selectedTags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTags.map((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                deleteIcon:
                    const Icon(Icons.close, size: 16, color: Colors.white),
                onDeleted: () {
                  setState(() => _selectedTags.remove(tag));
                },
                backgroundColor: neonColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: neonColor.withOpacity(0.5)),
                ),
              );
            }).toList(),
          ),
        if (_selectedTags.isNotEmpty) const SizedBox(height: 12),

        // Trending tags
        if (_trendingTags.isNotEmpty) ...[
          Text(
            'Trending 🔥',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trendingTags.take(5).map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isSelected) {
                      _selectedTags.remove(tag);
                    } else if (_selectedTags.length < 3) {
                      _selectedTags.add(tag);
                    }
                  });
                },
                child: Chip(
                  label: Text(
                    tag,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),
                  backgroundColor: isSelected
                      ? neonColor.withOpacity(0.3)
                      : Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected
                          ? neonColor.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildVisibilitySection(ThemeData theme, Color neonColor) {
    final options = [
      {
        'value': 'group_private',
        'label': 'Group Only',
        'icon': Icons.lock,
        'description': 'Only group members can see',
      },
      {
        'value': 'friends_only',
        'label': 'Friends',
        'icon': Icons.people,
        'description': 'Friends can see and join',
      },
      {
        'value': 'public',
        'label': 'Public',
        'icon': Icons.public,
        'description': 'Anyone can see and join',
      },
    ];

    return Column(
      children: options.map((option) {
        final isSelected = _visibility == option['value'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _visibility = option['value'] as String);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? neonColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    option['icon'] as IconData,
                    color:
                        isSelected ? neonColor : Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          option['description'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: neonColor,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMaxSpotsSlider(ThemeData theme, Color neonColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Players: $_maxSpots',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            Text(
              '2-12',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: neonColor,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: neonColor,
            overlayColor: neonColor.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: _maxSpots.toDouble(),
            min: 2,
            max: 12,
            divisions: 10,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              setState(() => _maxSpots = value.toInt());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton(ThemeData theme, Color neonColor) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  neonColor.withOpacity(0.8),
                  neonColor.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: neonColor.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: neonColor.neonGlow(blur: 16, opacity: 0.4),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _createLobby,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.rocket_launch,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Create Lobby',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
