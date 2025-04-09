import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'squad_tab/squad_queue_logic.dart';

class PerformanceHubTab extends StatelessWidget {
  final SquadQueueLogic logic;

  const PerformanceHubTab({super.key, required this.logic});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Recent Performance'),
            RecentStatsSection(logic: logic),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Historical Stats'),
            HistoricalStatsSection(logic: logic),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Leaderboards'),
            LeaderboardsSection(logic: logic),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class RecentStatsSection extends StatelessWidget {
  final SquadQueueLogic logic;

  const RecentStatsSection({super.key, required this.logic});

  @override
  Widget build(BuildContext context) {
    final recentStats = _calculateRecentStats();
    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(title: 'Wins', value: recentStats['wins'].toString()),
            _StatCard(title: 'Losses', value: recentStats['losses'].toString()),
            _StatCard(
                title: 'K/D Ratio',
                value: recentStats['kdRatio'].toStringAsFixed(2)),
            _StatCard(
                title: 'Rating',
                value: recentStats['rating'].toStringAsFixed(1)),
            _StatCard(
                title: 'Complaints',
                value: recentStats['complaints'].toString()),
          ],
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateRecentStats() {
    final recentGames = logic.gameHistory.take(10).toList(); // Last 10 games
    final wins = recentGames.where((g) => g['result'] == 'Win').length;
    final losses = recentGames.length - wins;
    final kills = recentGames.fold<int>(0, (sum, g) => sum + (g['kills'] as int? ?? 0));
    final deaths = recentGames.fold<int>(0, (sum, g) => sum + (g['deaths'] as int? ?? 0));
    final kdRatio = deaths > 0 ? kills / deaths : kills.toDouble();
    final rating = (wins * 10 + kills * 0.5 - deaths * 0.2).clamp(0, 100); // Example formula
    final complaints = recentGames.fold<int>(0, (sum, g) => sum + (g['complaints'] as int? ?? 0));

    return {
      'wins': wins,
      'losses': losses,
      'kdRatio': kdRatio,
      'rating': rating,
      'complaints': complaints,
    };
  }
}

class HistoricalStatsSection extends StatefulWidget {
  final SquadQueueLogic logic;

  const HistoricalStatsSection({super.key, required this.logic});

  @override
  State<HistoricalStatsSection> createState() => _HistoricalStatsSectionState();
}

class _HistoricalStatsSectionState extends State<HistoricalStatsSection> {
  GameStats? importedStats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _importStats,
          icon: const Icon(Icons.upload),
          label: const Text('Import Historical Stats'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        if (importedStats == null)
          const Text(
            'No historical stats imported yet.',
            style: TextStyle(color: Colors.grey),
          )
        else
          Column(
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                      title: 'Total Games',
                      value: importedStats!.totalGames.toString()),
                  _StatCard(
                      title: 'K/D Ratio',
                      value: importedStats!.kdRatio.toStringAsFixed(2)),
                  _StatCard(
                      title: 'Win Rate',
                      value: '${(importedStats!.winRate * 100).toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 16),
              _TrendChart(
                title: 'Historical K/D Trend',
                spots: importedStats!.kdSpots,
                maxY: importedStats!.kdSpots.isNotEmpty
                    ? importedStats!.kdSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2
                    : 5.0,
              ),
            ],
          ),
      ],
    );
  }

  void _importStats() async {
    // Placeholder for file picker or API call
    // For demo, we'll simulate imported data
    setState(() {
      importedStats = GameStats(
        kdRatio: 1.8,
        winRate: 0.65,
        totalGames: 150,
        totalKills: 450,
        totalDeaths: 250,
        kdSpots: List.generate(50, (i) => FlSpot(i.toDouble(), 1.5 + (i % 5) * 0.2)),
        winRateSpots: [],
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stats imported successfully!')),
    );
  }
}

class LeaderboardsSection extends StatelessWidget {
  final SquadQueueLogic logic;

  const LeaderboardsSection({super.key, required this.logic});

  @override
  Widget build(BuildContext context) {
    final leaderboard = _calculateLeaderboard(logic.squadMembers);
    return Card(
      elevation: 4,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Squad Leaderboard',
              style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (leaderboard.isEmpty)
              const Text('No data available', style: TextStyle(color: Colors.grey))
            else
              ...leaderboard.take(5).map((entry) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.cyanAccent,
                      child: Text(
                        entry['name'][0],
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    title: Text(entry['name'], style: const TextStyle(color: Colors.white)),
                    trailing: Text('${entry['wins']} wins',
                        style: const TextStyle(color: Colors.cyanAccent)),
                  )),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _calculateLeaderboard(List<String> members) {
    return members.map((member) {
      final wins = widget.logic.gameHistory
          .where((game) => (game['players'] as List?)?.contains(member) == true && game['result'] == 'Win')
          .length;
      return {'name': member, 'wins': wins};
    }).toList()
      ..sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: Colors.cyanAccent, fontSize: 14)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final String title;
  final List<FlSpot> spots;
  final double maxY;

  const _TrendChart({required this.title, required this.spots, required this.maxY});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 5),
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
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.cyanAccent,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Colors.cyanAccent.withValues(alpha: 0.1)),
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
}

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