import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/game.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../widgets/game_search_delegate.dart';
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTrendingTags() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('tag_analytics')
          .select('tag_name, trending_score')
          .gt('trending_score', 5.0)
          .order('trending_score', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _trendingTags = (response as List)
              .map((tag) => tag['tag_name'] as String)
              .toList();
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

      // Create lobby with tags and visibility
      final lobbyId = await lobbyNotifier.createLobby(
        chatGroupId: widget.chatGroupId,
        gameName: _selectedGame!.name,
        maxSpots: _maxSpots,
        isPublic: _visibility == 'public',
      );

      // Update lobby metadata
      final supabase = Supabase.instance.client;
      await supabase.from('lobbies').update({
        'tags': _selectedTags,
        'visibility': _visibility,
      }).eq('id', lobbyId);

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
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final game = await showSearch(
          context: context,
          delegate: GameSearchDelegate(ref: ref),
        );
        if (game != null) {
          setState(() => _selectedGame = game);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (_selectedGame != null)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Icon(Icons.gamepad, color: neonColor, size: 24),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withOpacity(0.05),
                ),
                child: Icon(Icons.add,
                    color: Colors.white.withOpacity(0.5), size: 24),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedGame?.name ?? 'Tap to select game',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _selectedGame != null
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.3),
              size: 20,
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
