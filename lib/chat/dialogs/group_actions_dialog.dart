import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/auth_service_supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/game.dart';
import '../../presentation/notifiers/chat_notifier.dart';
import '../../presentation/notifiers/game_notifier.dart';
import '../../widgets/game_tile.dart';
import '../../widgets/unified_game_selection_sheet.dart';
import '../chat_screen.dart';

/// Full-page screen for creating a new group with animated glass theme
class GroupActionsDialog extends ConsumerStatefulWidget {
  const GroupActionsDialog({super.key});

  @override
  ConsumerState<GroupActionsDialog> createState() => _GroupActionsDialogState();
}

class _GroupActionsDialogState extends ConsumerState<GroupActionsDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    await _animationController.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleBack();
        return false;
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Full-screen blur for liquid glass effect
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ),
            // Main content
            Scaffold(
              backgroundColor: Colors.transparent,
              body: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // Custom app bar matching ChatInfoScreen
                    _buildAppBar(context),

                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 16),

                            // Content
                            _CreateGroupTab(),

                            const SizedBox(height: 32),
                          ],
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
  }

  Widget _buildAppBar(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Back button with glass effect
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _handleBack,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Title with icon
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group_add,
                      color: Colors.cyanAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Group',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Build your gaming community',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab for creating a new group with optional members and games
class _CreateGroupTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateGroupTab> createState() => _CreateGroupTabState();
}

class _CreateGroupTabState extends ConsumerState<_CreateGroupTab> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = false; // Default to private
  bool _isCreating = false;
  Game? _selectedGame;
  List<Game> _popularGames = [];
  bool _loadingGames = false;

  @override
  void initState() {
    super.initState();
    _loadPopularGames();
  }

  Future<void> _loadPopularGames() async {
    setState(() => _loadingGames = true);
    try {
      final result =
          await ref.read(gameNotifierProvider.notifier).loadPopularGames();
      result.when(
        data: (games) {
          if (mounted) {
            setState(() {
              _popularGames = games.take(10).toList(); // Top 10 popular games
              _loadingGames = false;
            });
          }
        },
        loading: () {},
        error: (e, st) {
          if (mounted) {
            setState(() => _loadingGames = false);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loadingGames = false);
      }
    }
  }

  Future<void> _showGameSearch() async {
    await UnifiedGameSelectionSheet.show(
      context,
      title: 'Select Game Focus',
      subtitle: 'Choose a game for this group',
      showPinnedGames: false,
      showSearchButton: true,
      showMaxSpotSelector: false,
      onGameSelected: (game) {
        if (mounted) {
          setState(() {
            _selectedGame = game;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Create group
  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      showSnackBar(context, 'Please enter a group name');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final currentUser = AuthServiceSupabase().currentUser;
      if (currentUser == null) return;

      // Use proper repository pattern
      final chatNotifier = ref.read(chatNotifierProvider.notifier);

      // Build description
      String? description = _descriptionController.text.trim();
      if (description.isEmpty) description = null;

      // Add game focus to description if selected
      if (_selectedGame != null) {
        final gameName = _selectedGame!.name;
        description =
            description != null ? '$description\n🎮 $gameName' : '🎮 $gameName';
      }

      // Create group
      final newGroup = await chatNotifier.createGroup(
        groupName,
        _isPublic,
        description: description,
      );

      if (mounted && newGroup != null) {
        Navigator.pop(context);
        showSnackBar(context, '✅ Group "$groupName" created!');

        // Navigate to the new chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatType: ChatType.userGroup,
              chatGroupId: newGroup.id,
              chatGroupName: newGroup.name,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error creating group: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Name Glass Card
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.group, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Group Name *',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildGlassTextField(
                  controller: _nameController,
                  hintText: 'Enter group name...',
                  prefixIcon: Icons.group,
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Description Glass Card
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Description (Optional)',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildGlassTextField(
                  controller: _descriptionController,
                  hintText: 'What is this group about?',
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Game Focus Glass Card
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.videogame_asset,
                            color: Colors.cyanAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Game Focus',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _showGameSearch,
                      icon: const Icon(Icons.search,
                          size: 18, color: Colors.cyanAccent),
                      label: Text(
                        'Search',
                        style: GoogleFonts.inter(color: Colors.cyanAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedGame != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.cyanAccent.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            GameTile(
                              game: _selectedGame!,
                              style: GameTileStyle.list,
                              onTap: () {
                                setState(() => _selectedGame = null);
                              },
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color: Colors.red.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedGame = null);
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  _buildPopularGamesCarousel(),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Privacy & Settings Glass Card
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Privacy',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: SwitchListTile(
                        value: _isPublic,
                        onChanged: (value) => setState(() => _isPublic = value),
                        title: Text(
                          'Public Group',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          _isPublic
                              ? 'Anyone can find and join this group'
                              : 'Only invited members can join',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                        activeColor: Colors.cyanAccent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Create Button
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyanAccent.withOpacity(0.8),
                        Colors.cyanAccent.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Create Group',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
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
          padding: const EdgeInsets.all(20),
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

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
            maxLines: maxLines,
            textCapitalization: textCapitalization,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.4),
              ),
              filled: false,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: Colors.cyanAccent.withOpacity(0.7))
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularGamesCarousel() {
    if (_loadingGames) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    if (_popularGames.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No popular games available',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _popularGames.length,
        itemBuilder: (context, index) {
          final game = _popularGames[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GameTile(
              game: game,
              style: GameTileStyle.grid,
              onTap: () {
                setState(() => _selectedGame = game);
              },
            ),
          );
        },
      ),
    );
  }
}
