import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../domain/entities/app_user.dart';

class PerformanceStatsScreen extends ConsumerWidget {
  const PerformanceStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Performance Stats',
          style: GoogleFonts.robotoMono(
            fontWeight: FontWeight.bold,
            color: Colors.cyan,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.cyan),
      ),
      backgroundColor: Colors.black,
      body: userAsync.when(
        data: (user) =>
            user != null ? _buildStatsContent(user) : _buildNoUserContent(),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.cyan),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error loading stats: $error',
            style: GoogleFonts.robotoMono(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildNoUserContent() {
    return Center(
      child: Text(
        'No user data available',
        style: GoogleFonts.robotoMono(color: Colors.white),
      ),
    );
  }

  Widget _buildStatsContent(AppUser user) {
    final totalGames = _calculateTotalGames(user);
    final averageRating = _calculateAverageRating(user);
    final totalComplaints = _calculateTotalComplaints(user);
    final totalBans = _calculateTotalBans(user);
    final activeStreaks = _calculateActiveStreaks(user);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Stats
          _buildStatsCard(
            'Overall Performance',
            [
              _buildStatRow('Total Games Played', totalGames.toString()),
              _buildStatRow('Average Rating', averageRating),
              _buildStatRow('Active Streaks', activeStreaks.toString()),
            ],
          ),

          const SizedBox(height: 20),

          // Game-specific Ratings
          if (user.allTimeRatings.isNotEmpty) ...[
            _buildStatsCard(
              'Game Ratings',
              user.allTimeRatings.entries.map((entry) {
                final gameName = entry.key;
                final ratings = entry.value;
                final gameAverage = _calculateGameAverage(ratings);
                return _buildStatRow(gameName, gameAverage);
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Complaints & Bans
          _buildStatsCard(
            'Community Standing',
            [
              _buildStatRow(
                  'Total Complaints Filed', totalComplaints.toString()),
              _buildStatRow('Total Bans Received', totalBans.toString()),
              _buildStatRow('Friends Count', user.friends.length.toString()),
            ],
          ),

          const SizedBox(height: 20),

          // Current Streaks
          if (user.currentStreaks.isNotEmpty) ...[
            _buildStatsCard(
              'Current Streaks',
              user.currentStreaks.entries.map((entry) {
                return _buildStatRow(entry.key, '${entry.value} games');
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Achievement Progress
          _buildStatsCard(
            'Achievement Progress',
            [
              _buildStatRow('Pinned Games', user.pinnedGames.length.toString()),
              _buildStatRow('User Groups', user.userGroups.length.toString()),
              _buildStatRow(
                  'Alert Circles', user.alertCircles.length.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(String title, List<Widget> stats) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final neonColor = theme.colorScheme.primary;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: neonColor.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: neonColor.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.robotoMono(
                      color: neonColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...stats,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.robotoMono(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              color: Colors.cyan,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTotalGames(AppUser user) {
    int total = 0;
    user.allTimeRatings.forEach((game, ratings) {
      total += ratings.length;
    });
    user.dailyRatings.forEach((game, ratings) {
      total += ratings.length;
    });
    return total;
  }

  String _calculateAverageRating(AppUser user) {
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

  String _calculateGameAverage(Map<String, int> ratings) {
    if (ratings.isEmpty) return '0.0★';

    double total = 0;
    ratings.forEach((player, rating) {
      total += rating.toDouble();
    });

    final average = total / ratings.length;
    return '${average.toStringAsFixed(1)}★';
  }

  int _calculateTotalComplaints(AppUser user) {
    int total = 0;
    user.complaints.forEach((game, complaints) {
      total += complaints.length;
    });
    return total;
  }

  int _calculateTotalBans(AppUser user) {
    int total = 0;
    user.bans.forEach((game, bans) {
      total += bans.length;
    });
    return total;
  }

  int _calculateActiveStreaks(AppUser user) {
    int total = 0;
    user.currentStreaks.forEach((game, streak) {
      if (streak > 0) total++;
    });
    return total;
  }
}
