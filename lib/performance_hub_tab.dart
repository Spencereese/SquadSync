import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'squad_queue.dart';

class PerformanceHubTab extends StatelessWidget {
  final SquadQueuePageState state;

  const PerformanceHubTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    debugPrint('PerformanceHubTab building');
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.of(context).size.height - kToolbarHeight - 64,
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
                physics: BouncingScrollPhysics(),
                children: [
                  PersonalStatsView(state: state),
                  LeaderboardsView(state: state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data model for game statistics
class GameStats {
  final double kdRatio;
  final double winRate;
  final int totalGames;
  final int totalKills;
  final int totalDeaths;
  final List<FlSpot> kdSpots;
  final List<FlSpot> winRateSpots;

  GameStats({
    required this.kdRatio,
    required this.winRate,
    required this.totalGames,
    required this.totalKills,
    required this.totalDeaths,
    required this.kdSpots,
    required this.winRateSpots,
  });
}

class PersonalStatsView extends StatelessWidget {
  final SquadQueuePageState state;

  const PersonalStatsView({super.key, required this.state});

  GameStats _calculateStats() {
    final gameHistory = state.gameHistory;
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

    return GameStats(
      kdRatio: kdRatio,
      winRate: winRate,
      totalGames: totalGames,
      totalKills: totalKills,
      totalDeaths: totalDeaths,
      kdSpots: kdSpots,
      winRateSpots: winRateSpots,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'PersonalStatsView building, gameHistory length: ${state.gameHistory.length}');
    final stats = _calculateStats();

    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            _MetricCard(
              title: 'Total Kills',
              value: stats.totalKills.toString(),
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
                  color: Colors.grey.withOpacity(0.2),
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
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
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
                    color: Colors.cyanAccent.withOpacity(0.1),
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

class LeaderboardsView extends StatelessWidget {
  final SquadQueuePageState state;

  const LeaderboardsView({super.key, required this.state});

  List<Map<String, dynamic>> _calculateLeaderboard(List<String> members) {
    return members.map((member) {
      final wins = state.gameHistory
          .where((game) =>
              (game['players'] as List?)?.contains(member) == true &&
              game['result'] == 'Win')
          .length;
      return {'name': member, 'wins': wins};
    }).toList()
      ..sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'LeaderboardsView building, squadMembers: ${state.squadMembers.length}');
    final squadLeaderboard = _calculateLeaderboard(state.squadMembers);
    // For demo purposes, global uses same data. In real app, fetch from server
    final globalLeaderboard = squadLeaderboard;

    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                (entry) => ListTile(
                  leading: const Icon(Icons.person, color: Colors.cyanAccent),
                  title: Text(entry['name'],
                      style: const TextStyle(color: Colors.white)),
                  trailing: Text(
                    '${entry['wins']} wins',
                    style: const TextStyle(color: Colors.cyanAccent),
                  ),
                ),
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
                (entry) => ListTile(
                  leading: const Icon(Icons.person, color: Colors.cyanAccent),
                  title: Text(entry['name'],
                      style: const TextStyle(color: Colors.white)),
                  trailing: Text(
                    '${entry['wins']} wins',
                    style: const TextStyle(color: Colors.cyanAccent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
