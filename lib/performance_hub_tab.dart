import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'squad_state.dart';
import 'no_squad_screen.dart';

class PerformanceHubTab extends StatelessWidget {
  const PerformanceHubTab({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('PerformanceHubTab building');
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.only(top: kToolbarHeight),
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Personal Stats'),
                Tab(text: 'Leaderboards'),
              ],
              labelColor: Colors.cyanAccent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.cyanAccent,
              physics: BouncingScrollPhysics(),
            ),
            Expanded(
              child: TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  Consumer<SquadState>(
                    builder: (context, squadState, child) {
                      if (squadState.selectedSquadId == null) {
                        return const NoSquadScreen();
                      }
                      return PersonalStatsView(squadState: squadState);
                    },
                  ),
                  Consumer<SquadState>(
                    builder: (context, squadState, child) {
                      if (squadState.selectedSquadId == null) {
                        return const NoSquadScreen();
                      }
                      return LeaderboardsView(squadState: squadState);
                    },
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

class GameStats {
  final double kdRatio;
  final double winRate;
  final int totalGames;
  final int totalKills;
  final int totalDeaths;
  final List<FlSpot> kdSpots;
  final List<FlSpot> winRateSpots;
  final Map<String, double> ratings; // Added for ratings
  final int complaints; // Added for complaints

  GameStats({
    required this.kdRatio,
    required this.winRate,
    required this.totalGames,
    required this.totalKills,
    required this.totalDeaths,
    required this.kdSpots,
    required this.winRateSpots,
    required this.ratings,
    required this.complaints,
  });
}

class PersonalStatsView extends StatelessWidget {
  final SquadState squadState;

  const PersonalStatsView({super.key, required this.squadState});

  GameStats _calculateStats() {
    final gameHistory = squadState.gameHistory;
    final displayName = squadState.displayName ?? 'Unknown';
    final totalGames = gameHistory.length;
    final wins = gameHistory.where((game) => game['result'] == 'Win').length;
    final winRate = totalGames > 0 ? wins / totalGames : 0.0;
    final totalKills = gameHistory.fold<int>(
        0, (sum, game) => sum + (game['kills'] as int? ?? 0));
    final totalDeaths = gameHistory.fold<int>(
        0, (sum, game) => sum + (game['deaths'] as int? ?? 0));
    final kdRatio =
        totalDeaths > 0 ? totalKills / totalDeaths : totalKills.toDouble();

    List<FlSpot> kdSpots = [];
    List<FlSpot> winRateSpots = [];
    int cumulativeWins = 0;

    for (var i = 0; i < totalGames; i++) {
      final game = gameHistory[i];
      final kills = game['kills'] as int? ?? 0;
      final deaths = game['deaths'] as int? ?? 0;
      final kd = deaths > 0 ? kills / deaths : kills.toDouble();
      kdSpots.add(FlSpot(i.toDouble(), kd));
      cumulativeWins += game['result'] == 'Win' ? 1 : 0;
      final cumulativeWinRate = totalGames > 0 ? cumulativeWins / (i + 1) : 0.0;
      winRateSpots.add(FlSpot(i.toDouble(), cumulativeWinRate));
    }

    final ratings = squadState.getMemberRatings(displayName);
    final complaints = squadState.complaints[displayName] ?? 0;

    return GameStats(
      kdRatio: kdRatio,
      winRate: winRate,
      totalGames: totalGames,
      totalKills: totalKills,
      totalDeaths: totalDeaths,
      kdSpots: kdSpots,
      winRateSpots: winRateSpots,
      ratings: ratings,
      complaints: complaints,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'PersonalStatsView building, gameHistory length: ${squadState.gameHistory.length}');
    final stats = _calculateStats();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0).copyWith(bottom: 80.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MetricCard(
                  title: 'K/D Ratio',
                  value: stats.kdRatio.toStringAsFixed(2),
                ),
                _MetricCard(
                  title: 'Win Rate',
                  value: '${(stats.winRate * 100).toStringAsFixed(1)}%',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MetricCard(
                  title: 'Total Kills',
                  value: stats.totalKills.toString(),
                ),
                _MetricCard(
                  title: 'Complaints',
                  value: stats.complaints.toString(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Chart(
              title: 'K/D Trend',
              spots: stats.kdSpots,
              maxY: stats.kdSpots.isNotEmpty
                  ? stats.kdSpots
                          .map((e) => e.y)
                          .reduce((a, b) => a > b ? a : b) *
                      1.2
                  : 5.0,
            ),
            const SizedBox(height: 16),
            _Chart(
              title: 'Win Rate Trend',
              spots: stats.winRateSpots,
              maxY: 1.2,
            ),
            const SizedBox(height: 16),
            _RadarChart(
              title: 'Ratings Overview',
              ratings: stats.ratings,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  final String title;
  final List<FlSpot> spots;
  final double maxY;

  const _Chart({required this.title, required this.spots, required this.maxY});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.2),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.cyanAccent,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.cyanAccent.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarChart extends StatelessWidget {
  final String title;
  final Map<String, double> ratings;

  const _RadarChart({required this.title, required this.ratings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.circle,
              tickCount: 5,
              ticksTextStyle: const TextStyle(color: Colors.transparent),
              dataSets: [
                RadarDataSet(
                  fillColor: Colors.cyanAccent.withValues(alpha: 0.2),
                  borderColor: Colors.cyanAccent,
                  borderWidth: 2,
                  dataEntries: [
                    RadarEntry(value: ratings['Vibes'] ?? 0),
                    RadarEntry(value: ratings['Comms'] ?? 0),
                    RadarEntry(value: ratings['Gunny'] ?? 0),
                    RadarEntry(value: ratings['Wingman'] ?? 0),
                  ],
                ),
              ],
              titlePositionPercentageOffset: 0.1,
              getTitle: (index, angle) {
                switch (index) {
                  case 0:
                    return RadarChartTitle(text: 'Vibes');
                  case 1:
                    return RadarChartTitle(text: 'Comms');
                  case 2:
                    return RadarChartTitle(text: 'Gunny');
                  case 3:
                    return RadarChartTitle(text: 'Wingman');
                  default:
                    return RadarChartTitle(text: '');
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class LeaderboardsView extends StatelessWidget {
  final SquadState squadState;

  const LeaderboardsView({super.key, required this.squadState});

  List<Map<String, dynamic>> _calculateLeaderboard(List<String> members) {
    final filteredMembers = squadState.getFilteredMembers;
    return members
        .where((member) => filteredMembers.contains(member))
        .map((member) {
      final wins = squadState.gameHistory
          .where((game) =>
              (game['players'] as List?)?.contains(member) == true &&
              game['result'] == 'Win')
          .length;
      final ratings = squadState.getMemberRatings(member);
      final dailyRatings = squadState.getMemberRatings(member, daily: true);
      final complaints = squadState.complaints[member] ?? 0;
      return {
        'name': member,
        'wins': wins,
        'ratings': ratings,
        'dailyRatings': dailyRatings,
        'complaints': complaints,
      };
    }).toList()
      ..sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'LeaderboardsView building, filteredMembers: ${squadState.getFilteredMembers.length}');
    final filteredMembers = squadState.getFilteredMembers;
    final squadLeaderboard = _calculateLeaderboard(filteredMembers);
    final globalLeaderboard = squadLeaderboard; // Placeholder for global data

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0).copyWith(bottom: 80.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Squad Leaderboard',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            if (squadLeaderboard.isEmpty)
              const Center(
                child: Text(
                  'No data available',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...squadLeaderboard.map(
                (entry) =>
                    _LeaderboardTile(entry: entry, squadState: squadState),
              ),
            const SizedBox(height: 24),
            Text(
              'Global Leaderboard',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            if (globalLeaderboard.isEmpty)
              const Center(
                child: Text(
                  'No data available',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...globalLeaderboard.map(
                (entry) =>
                    _LeaderboardTile(entry: entry, squadState: squadState),
              ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final SquadState squadState;

  const _LeaderboardTile({required this.entry, required this.squadState});

  void _showBlockDialog(BuildContext context) {
    final player = entry['name'] as String;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isBlocked = squadState.userBlocks[uid]?.containsKey(player) ?? false;
    final action = isBlocked ? 'Unblock' : 'Hide Player';
    final message = isBlocked
        ? 'Unblock $player? You will see each other\'s stats again.'
        : 'Hide $player\'s stats? This is mutual—they won\'t see yours either.';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(action, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (isBlocked) {
                squadState.unblockUser(player);
              } else {
                squadState.blockUser(player);
              }
              Navigator.of(dialogContext).pop();
            },
            child:
                Text(action, style: const TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratings = entry['ratings'] as Map<String, double>;
    final dailyRatings = entry['dailyRatings'] as Map<String, double>;
    final avgRating = ratings.values.where((v) => v > 0).isNotEmpty
        ? ratings.values.where((v) => v > 0).reduce((a, b) => a + b) /
            ratings.values.where((v) => v > 0).length
        : 0.0;

    return GestureDetector(
      onLongPress: () => _showBlockDialog(context),
      child: ExpansionTile(
        leading: const Icon(Icons.person, color: Colors.cyanAccent),
        title: Text(entry['name'], style: const TextStyle(color: Colors.white)),
        subtitle: Row(
          children: [
            Text('${entry['wins']} wins',
                style: const TextStyle(color: Colors.cyanAccent)),
            const SizedBox(width: 8),
            if (avgRating > 0)
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.yellowAccent, size: 16),
                  Text(avgRating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.yellowAccent)),
                ],
              ),
            if (entry['complaints'] > 0) ...[
              const SizedBox(width: 8),
              Text('${entry['complaints']} complaints',
                  style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('All-Time Ratings:',
                    style: TextStyle(color: Colors.white)),
                ...ratings.entries.map((e) => Text(
                    '${e.key}: ${e.value.toStringAsFixed(1)}/5',
                    style: const TextStyle(color: Colors.white))),
                const SizedBox(height: 8),
                const Text('Daily Ratings:',
                    style: TextStyle(color: Colors.white)),
                ...dailyRatings.entries.map((e) => Text(
                    '${e.key}: ${e.value.toStringAsFixed(1)}/5',
                    style: const TextStyle(color: Colors.white))),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.circle,
                      tickCount: 5,
                      ticksTextStyle:
                          const TextStyle(color: Colors.transparent),
                      dataSets: [
                        RadarDataSet(
                          fillColor: Colors.cyanAccent.withValues(alpha: 0.2),
                          borderColor: Colors.cyanAccent,
                          borderWidth: 2,
                          dataEntries: [
                            RadarEntry(value: ratings['Vibes'] ?? 0),
                            RadarEntry(value: ratings['Comms'] ?? 0),
                            RadarEntry(value: ratings['Gunny'] ?? 0),
                            RadarEntry(value: ratings['Wingman'] ?? 0),
                          ],
                        ),
                      ],
                      titlePositionPercentageOffset: 0.1,
                      getTitle: (index, angle) {
                        switch (index) {
                          case 0:
                            return RadarChartTitle(text: 'Vibes');
                          case 1:
                            return RadarChartTitle(text: 'Comms');
                          case 2:
                            return RadarChartTitle(text: 'Gunny');
                          case 3:
                            return RadarChartTitle(text: 'Wingman');
                          default:
                            return RadarChartTitle(text: '');
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
