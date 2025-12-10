import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifiers/game_notifier.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../domain/entities/game.dart';
import '../core/app_theme.dart';

/// Game selection bottom sheet for creating lobbies
///
/// Shows pinned games and IGDB search functionality
/// Used in both chat groups (private lobbies) and public lobby creation
class GameSelectionSheet extends ConsumerStatefulWidget {
  final Function(String gameName, int maxSpots) onGameSelected;
  final bool showPublicToggle;

  const GameSelectionSheet({
    super.key,
    required this.onGameSelected,
    this.showPublicToggle = false,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(String gameName, int maxSpots) onGameSelected,
    bool showPublicToggle = false,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GameSelectionSheet(
        onGameSelected: onGameSelected,
        showPublicToggle: showPublicToggle,
      ),
    );
  }

  @override
  ConsumerState<GameSelectionSheet> createState() => _GameSelectionSheetState();
}

class _GameSelectionSheetState extends ConsumerState<GameSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Game> _searchResults = [];
  bool _isSearching = false;
  int _selectedMaxSpots = 8;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchGames(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final gameNotifier = ref.read(gameNotifierProvider.notifier);
    final result = await gameNotifier.searchGames(query);

    result.when(
      data: (games) {
        if (mounted) {
          setState(() {
            _searchResults = games;
            _isSearching = false;
          });
        }
      },
      loading: () {},
      error: (error, stack) {
        if (mounted) {
          setState(() => _isSearching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Search error: $error')),
          );
        }
      },
    );
  }

  void _selectGame(String gameName) {
    HapticFeedback.mediumImpact();
    widget.onGameSelected(gameName, _selectedMaxSpots);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(userNotifierProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Game',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a game to create a lobby',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Max spots selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Max Spots:',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _selectedMaxSpots.toDouble(),
                    min: 2,
                    max: 12,
                    divisions: 10,
                    label: _selectedMaxSpots.toString(),
                    onChanged: (value) {
                      setState(() => _selectedMaxSpots = value.toInt());
                    },
                  ),
                ),
                Text(
                  _selectedMaxSpots.toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (query) {
                _searchGames(query);
              },
              decoration: InputDecoration(
                hintText: 'Search games (IGDB)',
                prefixIcon:
                    Icon(Icons.search, color: theme.colorScheme.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchGames('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
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
            ),
          ),

          // Game list
          Expanded(
            child: _buildGameList(theme, userAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildGameList(ThemeData theme, AsyncValue userAsync) {
    // Show search results if searching
    if (_searchController.text.isNotEmpty) {
      if (_isSearching) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_searchResults.isEmpty) {
        return Center(
          child: Text(
            'No games found',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        );
      }
      return _buildSearchResults(theme);
    }

    // Show pinned games
    return userAsync.when(
      data: (userState) {
        final pinnedGames = userState.pinnedGames;
        if (pinnedGames.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.gamepad_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No pinned games',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search for a game to get started',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pinnedGames.length,
          itemBuilder: (context, index) {
            final gameName = pinnedGames[index];
            return _buildGameTile(theme, gameName, null);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading pinned games: $error'),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final game = _searchResults[index];
        return _buildGameTile(theme, game.name, game.coverUrl);
      },
    );
  }

  Widget _buildGameTile(ThemeData theme, String gameName, String? coverUrl) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: coverUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  coverUrl,
                  width: 50,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.gamepad,
                    color: theme.colorScheme.primary,
                  ),
                ),
              )
            : Icon(Icons.gamepad, color: theme.colorScheme.primary),
        title: Text(
          gameName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        onTap: () => _selectGame(gameName),
      ),
    );
  }
}
