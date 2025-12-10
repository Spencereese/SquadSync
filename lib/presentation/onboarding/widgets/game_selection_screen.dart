import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/entities/game.dart';
import '../../notifiers/game_notifier.dart';
import '../../notifiers/user_notifier.dart';
import '../onboarding_notifier.dart';

class GameSelectionScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const GameSelectionScreen({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<GameSelectionScreen> createState() =>
      _GameSelectionScreenState();
}

class _GameSelectionScreenState extends ConsumerState<GameSelectionScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _selectedChipsController = ScrollController();

  Timer? _searchDebounce;
  List<Game> _searchResults = [];
  List<Game> _popularGames = [];
  List<Game> _selectedGames = [];
  String? _primaryGameSlug;
  bool _isSearching = false;
  bool _isLoadingSearch = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadPopularGames();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _selectedChipsController.dispose();
    _searchDebounce?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPopularGames() async {
    try {
      // Load from assets/popular_games.json
      final jsonString =
          await rootBundle.loadString('assets/popular_games.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      final popularFromAssets = jsonData
          .take(20)
          .map((json) => Game.fromIgdb(json as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _popularGames = popularFromAssets;
        });
      }

      // Optionally load trending from IGDB (in background)
      _loadTrendingGames();
    } catch (e) {
      debugPrint('Error loading popular games: $e');
    }
  }

  Future<void> _loadTrendingGames() async {
    try {
      final result =
          await ref.read(gameNotifierProvider.notifier).loadPopularGames();
      result.whenData((games) {
        if (mounted && games.isNotEmpty) {
          setState(() {
            // Merge with existing popular games, dedupe by slug
            final allGames = [..._popularGames, ...games];
            final Map<String, Game> deduped = {};
            for (final game in allGames) {
              deduped[game.slug] = game;
            }
            _popularGames = deduped.values.take(20).toList();
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading trending games: $e');
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    _searchDebounce?.cancel();

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

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final result =
          await ref.read(gameNotifierProvider.notifier).searchGames(query);

      result.when(
        data: (games) {
          if (mounted) {
            setState(() {
              _searchResults = games;
              _isLoadingSearch = false;
            });
          }
        },
        loading: () {
          if (mounted) {
            setState(() {
              _isLoadingSearch = true;
            });
          }
        },
        error: (error, stack) {
          if (mounted) {
            setState(() {
              _searchResults = [];
              _isLoadingSearch = false;
            });
          }
          debugPrint('Search error: $error');
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoadingSearch = false;
        });
      }
      debugPrint('Search exception: $e');
    }
  }

  void _toggleGameSelection(Game game) {
    HapticFeedback.selectionClick();

    setState(() {
      final index = _selectedGames.indexWhere((g) => g.slug == game.slug);

      if (index != -1) {
        // Remove game
        _selectedGames.removeAt(index);

        // If this was the primary game, set a new primary
        if (_primaryGameSlug == game.slug) {
          _primaryGameSlug =
              _selectedGames.isNotEmpty ? _selectedGames.first.slug : null;
        }
      } else {
        // Add game (max 6)
        if (_selectedGames.length < 6) {
          _selectedGames.add(game);

          // First selected game becomes primary
          if (_selectedGames.length == 1) {
            _primaryGameSlug = game.slug;
          }
        } else {
          // Show snackbar if max reached
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Maximum 6 games allowed'),
              backgroundColor: Colors.cyan.withOpacity(0.8),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });

    // Update onboarding state
    ref.read(onboardingProvider.notifier).setGames(
          _selectedGames.map((g) => g.slug).toList(),
        );
  }

  void _setPrimaryGame(String slug) {
    HapticFeedback.mediumImpact();
    setState(() {
      _primaryGameSlug = slug;
    });
  }

  Future<void> _completeSelection() async {
    if (_selectedGames.isEmpty) return;

    HapticFeedback.heavyImpact();

    try {
      // Save to onboarding state
      ref.read(onboardingProvider.notifier).setGames(
            _selectedGames.map((g) => g.slug).toList(),
          );

      // Save to user notifier (for pinnedGames)
      final userNotifier = ref.read(userNotifierProvider.notifier);
      for (final game in _selectedGames) {
        await userNotifier.addPinnedGame(game.toJson());
      }

      // Call completion callback with mounted check
      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      debugPrint('Error saving selected games: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving games: $e'),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayGames = _isSearching && _searchResults.isNotEmpty
        ? _searchResults
        : _popularGames;
    final showEmpty = _isSearching &&
        !_isLoadingSearch &&
        _searchResults.isEmpty &&
        _searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'SELECT YOUR GAMES',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.cyan,
                      letterSpacing: 3,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose up to 6 games',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.cyan.withOpacity(0.6),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildSearchBar(),
            ),

            const SizedBox(height: 20),

            // Popular games horizontal scroll
            if (!_isSearching) _buildPopularSection(),

            const SizedBox(height: 20),

            // Main grid
            Expanded(
              child:
                  showEmpty ? _buildEmptyState() : _buildGameGrid(displayGames),
            ),

            // Selected chips + Done button (fixed bottom)
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _searchFocusNode.hasFocus
              ? Colors.cyan
              : Colors.cyan.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: _searchFocusNode.hasFocus
            ? [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Search games...',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
              ),
              prefixIcon: _isLoadingSearch
                  ? const Padding(
                      padding: EdgeInsets.all(14.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
                      ),
                    )
                  : const Icon(Icons.search, color: Colors.cyan, size: 24),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.cyan),
                      onPressed: () {
                        _searchController.clear();
                        _searchFocusNode.unfocus();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularSection() {
    if (_popularGames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'POPULAR NOW',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.cyan.withOpacity(0.8),
              letterSpacing: 2,
              fontFamily: 'Orbitron',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            itemCount: _popularGames.take(15).length,
            itemBuilder: (context, index) {
              final game = _popularGames[index];
              final isSelected = _selectedGames.any((g) => g.slug == game.slug);

              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  onTap: () => _toggleGameSelection(game),
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.cyan
                            : Colors.cyan.withOpacity(0.3),
                        width: isSelected ? 3 : 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.cyan.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (game.coverUrl != null)
                            Image.network(
                              game.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  _buildPlaceholderCover(),
                            )
                          else
                            _buildPlaceholderCover(),
                          if (isSelected)
                            Container(
                              color: Colors.cyan.withOpacity(0.3),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.cyan,
                                  size: 32,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGameGrid(List<Game> games) {
    if (_isLoadingSearch) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyan),
      );
    }

    if (games.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return _buildGameCard(game);
      },
    );
  }

  Widget _buildGameCard(Game game) {
    final isSelected = _selectedGames.any((g) => g.slug == game.slug);

    return GestureDetector(
      onTap: () => _toggleGameSelection(game),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.cyan : Colors.cyan.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Game cover
              if (game.coverUrl != null)
                Image.network(
                  game.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      _buildPlaceholderCover(),
                )
              else
                _buildPlaceholderCover(),

              // Dark overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),

              // Glass effect
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                child: Container(
                  color: Colors.black.withOpacity(0.1),
                ),
              ),

              // Game name
              Positioned(
                bottom: 8,
                left: 6,
                right: 6,
                child: Text(
                  game.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Orbitron',
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                      )
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),

              // Selection indicator
              if (isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.cyan,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ).animate().scale(
            duration: 200.ms,
            curve: Curves.easeOut,
          ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Icon(
          Icons.sports_esports,
          color: Colors.cyan.withOpacity(0.3),
          size: 40,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.cyan.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching
                ? 'No games found'
                : 'Start typing or pick from popular',
            style: TextStyle(
              fontSize: 16,
              color: Colors.cyan.withOpacity(0.6),
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasSelection = _selectedGames.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border(
          top: BorderSide(
            color: Colors.cyan.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selected chips
              if (hasSelection)
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    controller: _selectedChipsController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedGames.length,
                    itemBuilder: (context, index) {
                      final game = _selectedGames[index];
                      final isPrimary = game.slug == _primaryGameSlug;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildSelectedChip(game, isPrimary),
                      );
                    },
                  ),
                ),

              if (hasSelection) const SizedBox(height: 12),

              // Done button
              GestureDetector(
                onTap: hasSelection ? _completeSelection : null,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: hasSelection
                            ? const LinearGradient(
                                colors: [Colors.cyan, Colors.purpleAccent],
                              )
                            : null,
                        color:
                            hasSelection ? null : Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: hasSelection
                            ? [
                                BoxShadow(
                                  color: Colors.cyan
                                      .withOpacity(_pulseAnimation.value * 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          hasSelection
                              ? 'DONE (${_selectedGames.length}/6)'
                              : 'SELECT AT LEAST 1 GAME',
                          style: TextStyle(
                            color: hasSelection ? Colors.white : Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedChip(Game game, bool isPrimary) {
    return GestureDetector(
      onTap: () => _toggleGameSelection(game),
      onLongPress: () => _setPrimaryGame(game.slug),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isPrimary ? Colors.yellow : Colors.cyan,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPrimary ? Colors.yellow : Colors.cyan).withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini game icon
            if (game.coverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  game.coverUrl!,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Icon(
                    Icons.sports_esports,
                    size: 20,
                    color: Colors.cyan.withOpacity(0.6),
                  ),
                ),
              )
            else
              Icon(
                Icons.sports_esports,
                size: 20,
                color: Colors.cyan.withOpacity(0.6),
              ),

            const SizedBox(width: 8),

            // Game name
            Text(
              game.name.length > 15
                  ? '${game.name.substring(0, 15)}...'
                  : game.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),

            // Primary star badge
            if (isPrimary) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.star,
                color: Colors.yellow,
                size: 16,
              ),
            ],

            // Remove button
            const SizedBox(width: 6),
            Icon(
              Icons.close,
              color: Colors.white.withOpacity(0.8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
