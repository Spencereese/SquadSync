import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../domain/entities/game.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../presentation/notifiers/user_notifier.dart';
import '../../widgets/game_search_delegate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Glass-themed lobby creation sheet that slides over the chat screen
/// Matches the animation and styling of the group chat menu
class LobbyCreationSheet extends ConsumerStatefulWidget {
  final String chatGroupId;

  const LobbyCreationSheet({
    super.key,
    required this.chatGroupId,
  });

  @override
  ConsumerState<LobbyCreationSheet> createState() => _LobbyCreationSheetState();
}

class _LobbyCreationSheetState extends ConsumerState<LobbyCreationSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Form state
  Game? _selectedGame;
  String _visibility = 'group_private';
  bool _isAvailableMode = false;
  bool _isLoading = false;
  int _maxSpots = 4;
  List<Map<String, dynamic>> _pinnedGames = [];
  bool _isVisibilityExpanded = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    // Start animation
    _animationController.forward();
    
    // Load pinned games
    _loadPinnedGames();
  }
  
  Future<void> _loadPinnedGames() async {
    final userState = ref.read(userNotifierProvider);
    if (userState.hasValue && userState.value != null) {
      setState(() {
        _pinnedGames = userState.value!.pinnedGames;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleStart() async {
    if (_isAvailableMode) {
      await _setAvailableStatus();
    } else {
      await _createLobby();
    }
  }

  Future<void> _createLobby() async {
    if (_selectedGame == null && !_isAvailableMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a game')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final lobbyNotifier = ref.read(ln.lobbyNotifierProvider.notifier);

      // Create lobby with visibility
      final lobbyId = await lobbyNotifier.createLobby(
        chatGroupId: widget.chatGroupId,
        gameName: _selectedGame!.name,
        maxSpots: _maxSpots,
        isPublic: _visibility == 'public',
      );

      // Update lobby metadata (visibility, constitution will be auto-applied)
      final supabase = Supabase.instance.client;
      await supabase.from('lobbies').update({
        'visibility': _visibility,
      }).eq('id', lobbyId);

      HapticFeedback.mediumImpact();
      await _dismiss();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lobby created for ${_selectedGame!.name}!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating lobby: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create lobby: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setAvailableStatus() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Update user availability status
      await supabase.from('users').update({
        'available_status': 'Available for games',
        'available_since': DateTime.now().toIso8601String(),
      }).eq('uid', user.id);

      HapticFeedback.mediumImpact();
      await _dismiss();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Your availability has been posted!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error setting availability: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set availability: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaleTransition(
      scale: _animation,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.85],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDragHandle(theme),
                    _buildHeader(theme, isDark),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: _buildContent(theme, isDark),
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

  Widget _buildDragHandle(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            _isAvailableMode ? 'Set Availability' : 'Create Lobby',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close,
                color: isDark ? Colors.white70 : Colors.grey[700]),
            onPressed: _dismiss,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Available Mode Toggle (simplified)
        _buildAvailableToggle(theme, isDark),
        const SizedBox(height: 20),

        if (!_isAvailableMode) ...[
          // Game Picker
          _buildGamePicker(theme, isDark),
          const SizedBox(height: 20),

          // Max Spots Selector
          _buildMaxSpotsSelector(theme, isDark),
          const SizedBox(height: 20),

          // Visibility Picker
          _buildVisibilityPicker(theme, isDark),
          const SizedBox(height: 24),
        ],

        // Start Button
        _buildStartButton(theme, isDark),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAvailableToggle(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Just Looking for Players',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Post availability without a specific game',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAvailableMode,
            onChanged: (value) {
              setState(() => _isAvailableMode = value);
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGamePicker(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey[900],
          ),
        ),
        const SizedBox(height: 12),

        // Selected game card or search + pinned games
        if (_selectedGame != null)
          _buildSelectedGameCard(theme, isDark)
        else ...[
          // Search bar
          _buildCompactSearchBar(theme, isDark),
          const SizedBox(height: 12),

          // Pinned games carousel
          if (_pinnedGames.isNotEmpty) ...[
            Text(
              'Pinned Games',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            _buildPinnedGamesCarousel(theme, isDark),
          ] else
            _buildNoPinnedGames(theme, isDark),
        ],
      ],
    );
  }

  Widget _buildSelectedGameCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
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
                width: 50,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 50,
                  height: 70,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                  child: const Icon(Icons.gamepad, size: 30),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedGame!.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                color: isDark ? Colors.white70 : Colors.grey[700]),
            onPressed: () => setState(() => _selectedGame = null),
            tooltip: 'Clear selection',
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSearchBar(ThemeData theme, bool isDark) {
    return InkWell(
      onTap: () async {
        final game = await showSearch<Game?>(
          context: context,
          delegate: GameSearchDelegate(ref: ref),
        );
        if (game != null) {
          setState(() => _selectedGame = game);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Search for a game',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPinnedGamesCarousel(ThemeData theme, bool isDark) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pinnedGames.length,
        itemBuilder: (context, index) {
          final game = _pinnedGames[index];
          final gameName = game['name'] as String?;
          final coverUrl = game['cover_url'] as String?;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedGame = Game(
                  name: gameName ?? 'Unknown',
                  slug: (game['slug'] as String?) ?? '',
                  igdbId: game['id'] as int? ?? game['igdbId'] as int?,
                  coverUrl: coverUrl,
                  summary: game['summary'] as String?,
                  firstReleaseDate: null,
                  genres: const <String>[],
                  platforms: const <String>[],
                  maxSpots: game['maxSpots'] as int?,
                  isCached: false,
                  cachedAt: null,
                );
              });
              HapticFeedback.selectionClick();
            },
            child: Container(
              width: 75,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
              child: Column(
                children: [
                  // Game cover
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            width: 75,
                            height: 75,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: isDark ? Colors.grey[800] : Colors.grey[300],
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: isDark ? Colors.grey[800] : Colors.grey[300],
                              child: const Icon(Icons.gamepad, size: 30),
                            ),
                          )
                        : Container(
                            width: 75,
                            height: 75,
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            child: const Icon(Icons.gamepad, size: 30),
                          ),
                  ),
                  // Game name
                  Expanded(
                    child: Container(
                      width: 75,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        gameName ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white : Colors.grey[900],
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
          );
        },
      ),
    );
  }
  
  Widget _buildNoPinnedGames(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850]?.withOpacity(0.3) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.push_pin_outlined,
            color: isDark ? Colors.grey[500] : Colors.grey[500],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No pinned games. Pin games from your profile.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaxSpotsSelector(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Team Size',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_maxSpots players',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.cyan[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.cyan,
            inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
            thumbColor: Colors.cyan,
            overlayColor: Colors.cyan.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: _maxSpots.toDouble(),
            min: 2,
            max: 12,
            divisions: 10,
            label: '$_maxSpots',
            onChanged: (value) {
              setState(() => _maxSpots = value.toInt());
              HapticFeedback.selectionClick();
            },
          ),
        ),
      ],
    );
  }



  Widget _buildVisibilityPicker(ThemeData theme, bool isDark) {
    const visibilityOptions = {
      'group_private': {'label': 'Group Only', 'icon': Icons.group, 'description': 'Only group members can join'},
      'friends_only': {'label': 'Friends', 'icon': Icons.people, 'description': 'Your friends can join'},
      'public': {'label': 'Public', 'icon': Icons.public, 'description': 'Anyone can join'},
    };

    final selectedOption = visibilityOptions[_visibility]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who Can Join',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey[900],
          ),
        ),
        const SizedBox(height: 12),
        
        // Dropdown card
        InkWell(
          onTap: () {
            setState(() => _isVisibilityExpanded = !_isVisibilityExpanded);
            HapticFeedback.selectionClick();
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isVisibilityExpanded 
                    ? Colors.cyan.withOpacity(0.5)
                    : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                width: _isVisibilityExpanded ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                // Selected option display
                Row(
                  children: [
                    Icon(
                      selectedOption['icon'] as IconData,
                      size: 22,
                      color: Colors.cyan,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedOption['label'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[900],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedOption['description'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isVisibilityExpanded 
                          ? Icons.keyboard_arrow_up 
                          : Icons.keyboard_arrow_down,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ],
                ),
                
                // Expanded options
                if (_isVisibilityExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 1,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  
                  ...visibilityOptions.entries.where((e) => e.key != _visibility).map((entry) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _visibility = entry.key;
                          _isVisibilityExpanded = false;
                        });
                        HapticFeedback.selectionClick();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        child: Row(
                          children: [
                            Icon(
                              entry.value['icon'] as IconData,
                              size: 20,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.value['label'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : Colors.grey[900],
                                    ),
                                  ),
                                  Text(
                                    entry.value['description'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton(ThemeData theme, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleStart,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyan,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                _isAvailableMode ? 'Post Availability' : 'Create Lobby',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}
