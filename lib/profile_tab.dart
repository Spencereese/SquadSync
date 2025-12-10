import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/notifiers/user_notifier.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'presentation/notifiers/game_notifier.dart';
import 'screens/add_game_screen.dart';
import 'screens/squad_tab_screen.dart';
import 'screens/profile_editing_screen.dart';
import 'screens/availability_settings_screen.dart';
import 'screens/performance_stats_screen.dart';
import 'domain/entities/squad_state.dart';
import 'domain/entities/app_user.dart';
import 'core/app_theme.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  final ScrollController _scrollController = ScrollController();
  late ConfettiController _confettiController;

  // Notification settings
  bool _pushNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showPreviews = true;
  bool _quietHoursEnabled = false;
  TimeOfDay _quietStartTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEndTime = const TimeOfDay(hour: 8, minute: 0);
  bool _lobbyInvites = true;
  bool _friendRequests = true;
  bool _gameUpdates = false;
  bool _achievementAlerts = true;
  Set<String> _mutedGames = {};

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _loadNotificationSettings();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _scrollController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String _getStatusText() {
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

    return squadAsync.maybeWhen(
      data: (squadState) {
        // Check if in squad and playing a game
        if (squadState.selectedLobbyId != null &&
            squadState.currentGame != null) {
          final gameName = squadState.currentGame!['name'] ?? 'Game';
          return 'Playing $gameName';
        }

        // Check if in peacock queue
        if (squadState.peacockQueue.isNotEmpty) {
          final gameName = squadState.currentGame?['name'] ?? 'Game';
          return 'Looking for Squad · $gameName';
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
        height: 400, // Increased height to accommodate content
        child: Stack(
          children: [
            // Animated gradient background
            Builder(
              builder: (context) {
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                return Container(
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
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Add some top spacing to push content down slightly
                          const SizedBox(height: 20),
                          // Avatar with glowing border
                          AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, child) {
                              final theme = Theme.of(context);
                              final neonColor = theme.colorScheme.primary;
                              return SizedBox(
                                width: 140,
                                height: 140,
                                child: Center(
                                  child: Container(
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
                                ),
                              );
                            },
                          ).animate().scale(
                                duration: 600.ms,
                                curve: Curves.elasticOut,
                              ),

                          const SizedBox(height: 16),

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

                          const SizedBox(height: 12),

                          // Live status pill
                          StreamBuilder(
                            stream: Stream.periodic(const Duration(seconds: 1)),
                            builder: (context, snapshot) {
                              final theme = Theme.of(context);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withOpacity(0.7),
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
                ),
                orElse: () => Center(
                  child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),
              orElse: () => Center(
                child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary),
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
                      title: 'Squads This Week',
                      value: _calculateSquadsThisWeek(squadState),
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

  String _calculateSquadsThisWeek(LobbyState squadState) {
    // Calculate squads created/joined this week from gameHistory
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final recentSquads = squadState.gameHistory
        .where((game) =>
            game['timestamp'] != null &&
            DateTime.parse(game['timestamp']).isAfter(weekAgo))
        .length;

    return recentSquads.toString();
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

            // Games list
            userAsync.maybeWhen(
              data: (user) => gameAsync.maybeWhen(
                data: (gameState) => squadAsync.maybeWhen(
                  data: (squadState) {
                    final pinnedGames = user?.pinnedGames ?? [];
                    if (pinnedGames.isEmpty) {
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
            builder: (context) => SquadTabScreen(game: gameData),
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        Icons.add,
                        color: primaryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pin Your Games',
                      style: GoogleFonts.robotoMono(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add games to quickly access your squads',
                      style: GoogleFonts.robotoMono(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildStatsSection() {
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
              'GAMER STATS',
              style: GoogleFonts.robotoMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.cyan,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            // Placeholder for stats - will be implemented
            _buildStatRow('Total Games', '247'),
            _buildStatRow('Win Rate', '68.4%'),
            _buildStatRow('Hours Played', '1,234'),
            _buildStatRow('Current Streak', '12'),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.robotoMono(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: 16,
              color: Colors.cyan,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    // Placeholder achievements data - in real app this would come from AchievementManager
    final achievements = [
      {
        'title': 'First Win',
        'icon': Icons.emoji_events,
        'unlocked': true,
        'description': 'Win your first game'
      },
      {
        'title': 'Squad Leader',
        'icon': Icons.groups,
        'unlocked': true,
        'description': 'Lead 10 squads'
      },
      {
        'title': 'Voice Veteran',
        'icon': Icons.mic,
        'unlocked': false,
        'description': 'Use voice chat for 100 hours'
      },
      {
        'title': 'Game Master',
        'icon': Icons.videogame_asset,
        'unlocked': true,
        'description': 'Play 50 different games'
      },
      {
        'title': 'Streak Master',
        'icon': Icons.local_fire_department,
        'unlocked': false,
        'description': 'Win 10 games in a row'
      },
      {
        'title': 'Social Butterfly',
        'icon': Icons.people,
        'unlocked': true,
        'description': 'Add 20 friends'
      },
      {
        'title': 'Chat Champion',
        'icon': Icons.chat,
        'unlocked': false,
        'description': 'Send 1000 messages'
      },
      {
        'title': 'Loyal Player',
        'icon': Icons.loyalty,
        'unlocked': true,
        'description': 'Play for 30 days'
      },
    ];

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.purple.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACHIEVEMENTS',
              style: GoogleFonts.robotoMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: achievements.map((achievement) {
                return _buildAchievementBadge(
                  achievement['title'] as String,
                  achievement['icon'] as IconData,
                  achievement['unlocked'] as bool,
                  achievement['description'] as String,
                );
              }).toList(),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
    );
  }

  Widget _buildAchievementBadge(
      String title, IconData icon, bool unlocked, String description) {
    return GestureDetector(
      onTap: () => _showAchievementDialog(title, description, unlocked),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: unlocked
              ? Colors.purple.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: unlocked
                ? Colors.purple.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: unlocked ? Colors.purple : Colors.grey,
              size: 24,
            ).animate(target: unlocked ? 1 : 0).scale(
                  begin: const Offset(1.2, 1.2),
                  end: const Offset(1.0, 1.0),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.robotoMono(
                fontSize: 10,
                color: unlocked ? Colors.white : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ).animate(target: unlocked ? 1 : 0).scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration: 500.ms,
            curve: Curves.elasticOut,
          ),
    );
  }

  void _showAchievementDialog(String title, String description, bool unlocked) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.robotoMono(
            color: unlocked ? Colors.purple : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          unlocked ? '$description\n\nUnlocked! 🎉' : description,
          style: GoogleFonts.robotoMono(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.robotoMono(color: Colors.cyan),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    final userAsync = ref.watch(userNotifierProvider);
    final pinnedGames = userAsync.maybeWhen(
      data: (user) => user?.pinnedGames ?? [],
      orElse: () => [],
    );

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SETTINGS',
              style: GoogleFonts.robotoMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),

            // Notification Settings Header
            Text(
              'Notifications',
              style: GoogleFonts.robotoMono(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            _buildSettingRow('Push Notifications', _pushNotifications, (val) {
              setState(() => _pushNotifications = val);
              _saveSetting('pushNotifications', val);
            }),
            _buildSettingRow('Sound', _soundEnabled, (val) {
              setState(() => _soundEnabled = val);
              _saveSetting('soundEnabled', val);
            }, enabled: _pushNotifications),
            _buildSettingRow('Vibration', _vibrationEnabled, (val) {
              setState(() => _vibrationEnabled = val);
              _saveSetting('vibrationEnabled', val);
            }, enabled: _pushNotifications),
            _buildSettingRow('Show Previews', _showPreviews, (val) {
              setState(() => _showPreviews = val);
              _saveSetting('showPreviews', val);
            }, enabled: _pushNotifications),

            const Divider(height: 24, color: Colors.white24),

            // Alert Types
            Text(
              'Alert Types',
              style: GoogleFonts.robotoMono(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            _buildSettingRow('Lobby Invites', _lobbyInvites, (val) {
              setState(() => _lobbyInvites = val);
              _saveSetting('lobbyInvites', val);
            }),
            _buildSettingRow('Friend Requests', _friendRequests, (val) {
              setState(() => _friendRequests = val);
              _saveSetting('friendRequests', val);
            }),
            _buildSettingRow('Game Updates', _gameUpdates, (val) {
              setState(() => _gameUpdates = val);
              _saveSetting('gameUpdates', val);
            }),
            _buildSettingRow('Achievements', _achievementAlerts, (val) {
              setState(() => _achievementAlerts = val);
              _saveSetting('achievementAlerts', val);
            }),

            const Divider(height: 24, color: Colors.white24),

            // Quiet Hours
            _buildSettingRow('Quiet Hours', _quietHoursEnabled, (val) {
              setState(() => _quietHoursEnabled = val);
              _saveSetting('quietHoursEnabled', val);
            }),
            if (_quietHoursEnabled) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time,
                                  color: Colors.cyan, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _quietStartTime.format(context),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child:
                          Text('to', style: TextStyle(color: Colors.white70)),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time,
                                  color: Colors.cyan, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _quietEndTime.format(context),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 24, color: Colors.white24),

            // Game-specific muting
            if (pinnedGames.isNotEmpty) ...[
              Text(
                'Muted Games',
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ...pinnedGames.take(3).map((game) {
                final gameSlug = game['slug'] ?? game['name'] ?? '';
                final isMuted = _mutedGames.contains(gameSlug);
                return _buildSettingRow(
                  game['name'] ?? 'Unknown',
                  !isMuted,
                  (val) {
                    setState(() {
                      if (val) {
                        _mutedGames.remove(gameSlug);
                      } else {
                        _mutedGames.add(gameSlug);
                      }
                    });
                  },
                );
              }),
              if (pinnedGames.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${pinnedGames.length - 3} more games',
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      color: Colors.white54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),
    );
  }

  Widget _buildSettingRow(
      String label, bool value, ValueChanged<bool>? onChanged,
      {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.robotoMono(
              fontSize: 14,
              color: enabled ? Colors.white70 : Colors.white38,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _pushNotifications = prefs.getBool('pushNotifications') ?? true;
          _soundEnabled = prefs.getBool('soundEnabled') ?? true;
          _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
          _showPreviews = prefs.getBool('showPreviews') ?? true;
          _quietHoursEnabled = prefs.getBool('quietHoursEnabled') ?? false;
          _lobbyInvites = prefs.getBool('lobbyInvites') ?? true;
          _friendRequests = prefs.getBool('friendRequests') ?? true;
          _gameUpdates = prefs.getBool('gameUpdates') ?? false;
          _achievementAlerts = prefs.getBool('achievementAlerts') ?? true;

          // Load quiet hours times
          final quietStart = prefs.getString('quietStartTime');
          final quietEnd = prefs.getString('quietEndTime');
          if (quietStart != null) {
            final parts = quietStart.split(':');
            _quietStartTime = TimeOfDay(
                hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          if (quietEnd != null) {
            final parts = quietEnd.split(':');
            _quietEndTime = TimeOfDay(
                hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        });
      }
    } catch (e) {
      print('Error loading notification settings: $e');
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      print('Error saving setting $key: $e');
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _quietStartTime : _quietEndTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).cardColor,
              hourMinuteTextColor: Colors.white,
              dialHandColor: Colors.cyan,
              dialBackgroundColor: Colors.black26,
              entryModeIconColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStartTime) {
          _quietStartTime = picked;
          _saveSetting('quietStartTime', '${picked.hour}:${picked.minute}');
        } else {
          _quietEndTime = picked;
          _saveSetting('quietEndTime', '${picked.hour}:${picked.minute}');
        }
      });
    }
  }

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
                    'Edit Profile',
                    Icons.edit,
                    () {
                      // Navigate to profile editing screen
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
                    Icons.access_time,
                    () {
                      // Navigate to availability settings
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
                    'Performance',
                    Icons.bar_chart,
                    () {
                      // Navigate to performance stats
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
                      // TODO: Implement share functionality
                      try {
                        await Share.share(
                          'Check out my SquadSync profile! Join me for some gaming fun.',
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sharing not available on this platform',
                              style: GoogleFonts.robotoMono(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
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
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AvailabilitySettingsScreen(),
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
                _buildPinnedGamesSection(),
                _buildStatsSection(),
                _buildAchievementsSection(),
                _buildSettingsSection(),
                _buildQuickActionsSection(),
                // Add more sections as needed
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100), // Bottom padding
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
