import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import 'core/utils/image_crop_helper.dart';
import 'presentation/notifiers/user_notifier.dart';
import 'presentation/notifiers/game_notifier.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'screens/add_game_screen.dart';
import 'screens/lobby_tab_screen.dart';
import 'screens/profile_editing_screen.dart';
import 'screens/availability_settings_screen.dart';
import 'screens/performance_stats_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/last_five_rated_sessions.dart';
import 'domain/entities/lobby_state.dart';
import 'domain/entities/app_user.dart';
import 'core/app_theme.dart';
import 'services/supabase_service.dart';
import 'services/auth_service_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late ConfettiController _confettiController;
  String _gameSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _gameSearchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _pickAndUploadProfileImage() async {
    try {
      // Use ImageCropHelper for picking and cropping
      final croppedFile =
          await ImageCropHelper.pickAndCropProfileImage(context);

      if (croppedFile == null) return;

      if (!mounted) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Uploading profile picture...',
                  style: GoogleFonts.robotoMono(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      try {
        // Get current user ID for folder structure
        final user = AuthServiceSupabase().currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        // Upload image to avatars bucket with user_uid folder
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storagePath = '${user.id}/$fileName';

        // Read the cropped file bytes
        final bytes = await croppedFile.readAsBytes();

        // Upload to avatars bucket
        await SupabaseService.client.storage.from('avatars').uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );

        // Get public URL
        final imageUrl = SupabaseService.client.storage
            .from('avatars')
            .getPublicUrl(storagePath);

        // Update user profile
        final userNotifier = ref.read(userNotifierProvider.notifier);
        await userNotifier.updateProfileImage(imageUrl);

        if (!mounted) return;

        // Close loading dialog
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile picture updated!',
              style: GoogleFonts.robotoMono(),
            ),
            backgroundColor: AppTheme.success(Theme.of(context).colorScheme),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;

        // Close loading dialog
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to upload image: $e',
              style: GoogleFonts.robotoMono(),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to pick image: $e',
            style: GoogleFonts.robotoMono(),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String _getStatusText() {
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

    return squadAsync.maybeWhen(
      data: (squadState) {
        // Check if in lobby and playing a game
        if (squadState.selectedLobbyId != null &&
            squadState.currentGame != null) {
          final gameName = squadState.currentGame!['name'] ?? 'Game';
          return 'Playing $gameName';
        }

        // Check if in peacock queue
        if (squadState.peacockQueue.isNotEmpty) {
          final gameName = squadState.currentGame?['name'] ?? 'Game';
          return 'Looking for Lobby · $gameName';
        }

        // Check if has active timers
        if (squadState.spotTimerStates.isNotEmpty ||
            squadState.peacockTimerStates.isNotEmpty) {
          return 'Active in Squad';
        }

        // Default status
        return 'Online';
      },
      orElse: () => 'Loading...',
    );
  }

  Widget _buildHeroHeader() {
    final userAsync = ref.watch(userNotifierProvider);
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

    return SliverToBoxAdapter(
      child: Container(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Animated gradient background
            Builder(
              builder: (context) {
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                return Container(
                  height: 340,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.gradient1(colorScheme),
                        AppTheme.gradient2(colorScheme),
                        AppTheme.gradient3(colorScheme),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                )
                    .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                    .shimmer(
                  duration: 3000.ms,
                  colors: [
                    AppTheme.gradient1(colorScheme),
                    AppTheme.gradient2(colorScheme),
                    AppTheme.gradient1(colorScheme),
                  ],
                );
              },
            ),

            // Content overlay
            userAsync.maybeWhen(
              data: (user) => squadAsync.maybeWhen(
                data: (squadState) => SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar with seamless glowing border - now clickable
                        GestureDetector(
                          onTap: _pickAndUploadProfileImage,
                          child: AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, child) {
                              final theme = Theme.of(context);
                              final neonColor = theme.colorScheme.primary;
                              return Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: neonColor.withOpacity(
                                            _glowController.value * 0.8),
                                        width: 3,
                                      ),
                                      boxShadow: neonColor.neonGlow(
                                        blur: 30,
                                        spread: _glowController.value * 5,
                                        opacity: _glowController.value * 0.6,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: CircleAvatar(
                                        radius: 56,
                                        backgroundImage: user?.profileImage !=
                                                null
                                            ? NetworkImage(user!.profileImage!)
                                            : null,
                                        backgroundColor: theme.colorScheme
                                            .surfaceContainerHighest,
                                        child: user?.profileImage == null
                                            ? Icon(Icons.person,
                                                size: 40,
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withOpacity(0.7))
                                            : null,
                                      ),
                                    ),
                                  ),
                                  // Camera icon overlay
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: neonColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.colorScheme.surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 20,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ).animate().scale(
                              duration: 600.ms,
                              curve: Curves.elasticOut,
                            ),

                        const SizedBox(height: 8),

                        // Display name
                        Text(
                          user?.displayName ?? 'Gamer',
                          style: GoogleFonts.robotoMono(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ).animate().fadeIn(duration: 800.ms, delay: 200.ms),

                        const SizedBox(height: 8),

                        // Live status pill
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (context, snapshot) {
                            final theme = Theme.of(context);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surface.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color:
                                          AppTheme.success(theme.colorScheme),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                      .animate(
                                          onPlay: (controller) =>
                                              controller.repeat())
                                      .shimmer(duration: 1000.ms),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getStatusText(),
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ).animate().slideY(
                              begin: 0.5,
                              duration: 600.ms,
                              delay: 400.ms,
                              curve: Curves.elasticOut,
                            ),
                      ],
                    ),
                  ),
                ),
                orElse: () => Container(
                  height: 340,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
              orElse: () => Container(
                height: 340,
                child: Center(
                  child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final userAsync = ref.watch(userNotifierProvider);
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

    return SliverToBoxAdapter(
      child: Container(
        height: 140,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: userAsync.maybeWhen(
          data: (user) => squadAsync.maybeWhen(
            data: (squadState) => Builder(
              builder: (context) {
                final colorScheme = Theme.of(context).colorScheme;
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildStatCard(
                      title: 'Lobbies This Week',
                      value: _calculateLobbiesThisWeek(squadState),
                      icon: Icons.group,
                      color: AppTheme.gradient1(colorScheme),
                      delay: 0,
                    ),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      title: 'Rating',
                      value: _calculateAverageRating(user),
                      icon: Icons.star,
                      color: AppTheme.warning(colorScheme),
                      delay: 100,
                      showProgress: true,
                    ),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      title: 'Turkey Count',
                      value: _calculateTurkeyCount(user),
                      icon: Icons.restaurant,
                      color: AppTheme.warning(colorScheme).withBlue(50),
                      delay: 200,
                    ),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      title: 'Hours Played',
                      value: _calculateHoursPlayedThisMonth(user),
                      icon: Icons.schedule,
                      color: colorScheme.primary,
                      delay: 300,
                    ),
                  ],
                );
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildLastFiveRatedSessions() {
    final statsAsync = ref.watch(statsDashboardProvider);
    return SliverToBoxAdapter(
      child: statsAsync.maybeWhen(
        data: (snapshot) => YouLastFiveRatedSessions(
          sessions: snapshot.lastFiveRatedSessions,
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required int delay,
    bool showProgress = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: color.neonGlow(
              blur: 15,
              spread: 0,
              opacity: 0.3,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 6),
              if (showProgress && value.contains('★'))
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: _parseRating(value) / 5.0,
                    strokeWidth: 3,
                    backgroundColor: color.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Text(
                  value,
                  style: GoogleFonts.robotoMono(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 800.ms, delay: delay.ms).slideX(begin: 0.2);
  }

  String _calculateLobbiesThisWeek(LobbyState squadState) {
    // Calculate lobbies created/joined this week from gameHistory
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final recentLobbies = squadState.gameHistory
        .where((game) =>
            game['timestamp'] != null &&
            DateTime.parse(game['timestamp']).isAfter(weekAgo))
        .length;

    return recentLobbies.toString();
  }

  String _calculateAverageRating(AppUser? user) {
    if (user == null || user.allTimeRatings.isEmpty) return '0.0★';

    double totalRating = 0;
    int totalVotes = 0;

    user.allTimeRatings.forEach((game, ratings) {
      ratings.forEach((player, rating) {
        totalRating += rating.toDouble();
        totalVotes++;
      });
    });

    if (totalVotes == 0) return '0.0★';

    final average = totalRating / totalVotes;
    return '${average.toStringAsFixed(1)}★';
  }

  String _calculateTurkeyCount(AppUser? user) {
    if (user == null) return '0';

    // Count complaints (turkeys) given
    int turkeyCount = 0;
    user.complaints.forEach((game, complaints) {
      turkeyCount += complaints.length;
    });
    return turkeyCount.toString();
  }

  String _calculateHoursPlayedThisMonth(AppUser? user) {
    // This would need to be calculated from actual playtime data
    // For now, return a placeholder based on game history
    // Rough estimate: assume 2 hours per game session
    final recentGames = 12; // Placeholder
    final estimatedHours = recentGames * 2;

    return '${estimatedHours}h';
  }

  double _parseRating(String rating) {
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(rating);
    return double.tryParse(match?.group(1) ?? '0') ?? 0.0;
  }

  Widget _buildPinnedGamesSection() {
    final userAsync = ref.watch(userNotifierProvider);
    final gameAsync = ref.watch(gameNotifierProvider);
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) {
                      final primaryColor =
                          Theme.of(context).colorScheme.primary;
                      return Text(
                        'PINNED GAMES',
                        style: GoogleFonts.robotoMono(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 2,
                        ),
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      return IconButton(
                        icon: Icon(Icons.add,
                            color: Theme.of(context).colorScheme.primary),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AddGameScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms),

            const SizedBox(height: 16),

            // Search bar for games
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search your games...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.primary,
                  ),
                  suffixIcon: _gameSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white70),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1E2229),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 100.ms),

            const SizedBox(height: 16),

            // Games list
            userAsync.maybeWhen(
              data: (user) => gameAsync.maybeWhen(
                data: (gameState) => squadAsync.maybeWhen(
                  data: (squadState) {
                    var pinnedGames = user?.pinnedGames ?? [];

                    // Filter games based on search query
                    if (_gameSearchQuery.isNotEmpty) {
                      pinnedGames = pinnedGames.where((game) {
                        final gameName =
                            (game['name'] as String? ?? '').toLowerCase();
                        return gameName.contains(_gameSearchQuery);
                      }).toList();
                    }

                    if (pinnedGames.isEmpty) {
                      if (_gameSearchQuery.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No games found',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return _buildEmptyPinnedGames();
                    }
                    return SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: pinnedGames.length,
                        itemBuilder: (context, index) {
                          final pinnedGame = pinnedGames[index];
                          final gameName = pinnedGame['name'] as String? ?? '';
                          final isSelected =
                              squadState.currentGame?['name'] == gameName;

                          return _buildGameCard(
                            gameName: gameName,
                            coverUrl: pinnedGame['coverUrl'] as String?,
                            isSelected: isSelected,
                            delay: index * 100,
                          );
                        },
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required String gameName,
    required String? coverUrl,
    required bool isSelected,
    required int delay,
  }) {
    return GestureDetector(
      onTap: () {
        // Select the game
        final gameData = {
          'name': gameName,
          'coverUrl': coverUrl,
        };
        ref.read(gameNotifierProvider.notifier).selectGame(gameData);

        // Navigate to squad tab
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => LobbyTabScreen(game: gameData),
          ),
        );
      },
      child: Builder(
        builder: (context) {
          final primaryColor = Theme.of(context).colorScheme.primary;
          return Container(
            width: 160,
            height: 200,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.transparent,
                width: 2,
              ),
              boxShadow: isSelected
                  ? primaryColor.neonGlow(
                      blur: 20,
                      spread: 2,
                      opacity: 0.3,
                    )
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // Game cover
                  if (coverUrl != null)
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade800,
                        child: const Icon(
                          Icons.videogame_asset,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: Colors.grey.shade800,
                      child: const Icon(
                        Icons.videogame_asset,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),

                  // Platform icons - removed as requested
                  // Positioned(
                  //   top: 8,
                  //   right: 8,
                  //   child: Row(
                  //     children: platforms.take(3).map((platform) {
                  //       return Container(
                  //         margin: const EdgeInsets.only(left: 4),
                  //         padding: const EdgeInsets.all(4),
                  //         decoration: BoxDecoration(
                  //           color: Colors.black.withValues(alpha: 0.7),
                  //           borderRadius: BorderRadius.circular(8),
                  //         ),
                  //         child: Icon(
                  //           _getPlatformIcon(platform.toString()),
                  //           color: Colors.white,
                  //           size: 12,
                  //         ),
                  //       );
                  //     }).toList(),
                  //   ),
                  // ),

                  // Game name
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Text(
                      gameName,
                      style: GoogleFonts.robotoMono(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Selected indicator
                  if (isSelected)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
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
          );
        },
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms, delay: delay.ms)
        .scale(begin: Offset(0.9, 0.9));
  }

  Widget _buildEmptyPinnedGames() {
    return Builder(
      builder: (context) {
        final primaryColor = Theme.of(context).colorScheme.primary;
        return Container(
          height: 180,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddGameScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.add,
                        color: primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pin Your Games',
                      style: GoogleFonts.robotoMono(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add games to quickly access your lobbys',
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 800.ms).scale(begin: Offset(0.9, 0.9));
  }

  // Removed unused settings/stats/achievements sections - these are now in dedicated screens

  Widget _buildQuickActionsSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.cyan.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUICK ACTIONS',
              style: GoogleFonts.robotoMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.cyan,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: _buildQuickActionButton(
                    'Settings',
                    Icons.settings,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ProfileEditingScreen(),
                        ),
                      );
                    },
                  ),
                ),
                Flexible(
                  child: _buildQuickActionButton(
                    'Availability',
                    Icons.schedule,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const AvailabilitySettingsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                Flexible(
                  child: _buildQuickActionButton(
                    'Stats',
                    Icons.bar_chart,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PerformanceStatsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                Flexible(
                  child: _buildQuickActionButton(
                    'Share',
                    Icons.share,
                    () async {
                      try {
                        await Share.share(
                          'Check out my SquadSync profile! Join me for some gaming fun.',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Sharing not available',
                                style: GoogleFonts.robotoMono(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 1100.ms),
    );
  }

  Widget _buildQuickActionButton(
      String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyan.withValues(alpha: 0.1),
        foregroundColor: Colors.cyan,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.robotoMono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    // Simulate refreshing user data
    await Future.delayed(const Duration(milliseconds: 500));

    // Check for new achievements (placeholder logic)
    final hasNewAchievements = _checkForNewAchievements();

    if (hasNewAchievements && mounted) {
      // Show confetti for new achievements
      _confettiController.play();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New achievements unlocked! 🎉',
            style: GoogleFonts.robotoMono(),
          ),
          backgroundColor: Colors.purple,
          duration: const Duration(seconds: 3),
        ),
      );

      // Stop confetti after a few seconds
      Future.delayed(const Duration(seconds: 3), () {
        _confettiController.stop();
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile refreshed!',
            style: GoogleFonts.robotoMono(),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool _checkForNewAchievements() {
    // Placeholder: Simulate checking for new achievements
    // In real app, this would compare current achievements with previous state
    return DateTime.now().second % 3 == 0; // Random chance for demo
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () {
              // Navigate to comprehensive settings screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: Colors.cyan,
            backgroundColor: Colors.black87,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeroHeader(),
                _buildStatsCards(),
                _buildLastFiveRatedSessions(),
                _buildPinnedGamesSection(),
                _buildQuickActionsSection(),
                // Bottom padding for comfortable scrolling
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
          // Confetti widget for achievement celebrations
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.purple,
              Colors.cyan,
              Colors.pink,
              Colors.orange,
              Colors.green,
            ],
          ),
        ],
      ),
    );
  }
}
