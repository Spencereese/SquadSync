import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'package:squad_sync/services/session_rating_flow.dart';
import 'package:squad_sync/services/session_rating_machine.dart';

import '../presentation/notifiers/user_notifier.dart';
import '../widgets/last_five_rated_sessions.dart';
import 'stats_dashboard_data.dart';

/// Fetches `get_lobby_stats` + `match_history` once both user and lobby are ready.
///
/// Avoids painting empty charts from `LobbyState.gameHistory`, which recordMatch
/// never populates. Watches the lobby [AsyncValue] so membership-stream updates
/// (selected/current/userLobbies) refetch instead of freezing the first local
/// snapshot.
final statsDashboardProvider =
    FutureProvider.autoDispose<StatsDashboardSnapshot>((ref) async {
  ref.watch(ln.lobbyNotifierProvider);
  final user = await ref.watch(userNotifierProvider.future);
  final lobby = await ref.watch(ln.lobbyNotifierProvider.future);
  final repo = ref.watch(lobbyRepositoryProvider);
  return loadStatsDashboardSnapshot(
    user: user,
    lobby: lobby,
    fetchLobbyStats: repo.getLobbyStats,
    fetchMatchHistory: repo.getMatchHistory,
  );
});

/// Squad stats dashboard (streaks, win/loss, ratings).
///
/// Replaces the previous list-of-rows Stats screen. Opened from Profile → Stats.
class PerformanceStatsScreen extends ConsumerWidget {
  const PerformanceStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsDashboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        title: const Text('Stats'),
        backgroundColor: const Color(0xFF0B0E14),
        foregroundColor: Colors.cyanAccent,
        elevation: 0,
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load stats: $error',
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (snapshot) => StatsDashboardView(
          snapshot: snapshot,
          onRecordWin: _recordAction(context, ref, snapshot, result: 'win'),
          onRecordLoss: _recordAction(context, ref, snapshot, result: 'loss'),
          onSeedSmokeHistory:
              kDebugMode ? _seedSmokeHistory(context, ref, snapshot) : null,
        ),
      ),
    );
  }

  Future<void> Function()? _recordAction(
    BuildContext context,
    WidgetRef ref,
    StatsDashboardSnapshot snapshot, {
    required String result,
  }) {
    if (snapshot.statsLobbyIds.length != 1) return null;
    final lobbyId = snapshot.statsLobbyIds.first;
    return () async {
      try {
        final rating = await promptAndRecordEndedSession(
          context: context,
          ref: ref,
          lobbyId: lobbyId,
          result: result,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sessionRecordedSnackbar(result, rating))),
        );
        ref.invalidate(statsDashboardProvider);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record $result: $e')),
        );
      }
    };
  }

  Future<void> Function()? _seedSmokeHistory(
    BuildContext context,
    WidgetRef ref,
    StatsDashboardSnapshot snapshot,
  ) {
    if (snapshot.statsLobbyIds.length != 1) return null;
    final lobbyId = snapshot.statsLobbyIds.first;
    return () async {
      final notifier = ref.read(ln.lobbyNotifierProvider.notifier);
      try {
        await notifier.recordWin(lobbyId);
        await notifier.recordWin(lobbyId);
        await notifier.recordLoss(lobbyId);
        ref.invalidate(statsDashboardProvider);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to seed match history: $e')),
        );
      }
    };
  }
}

/// Phone-first dashboard body. Takes a snapshot so widget tests skip providers.
class StatsDashboardView extends StatelessWidget {
  const StatsDashboardView({
    super.key,
    required this.snapshot,
    this.onRecordWin,
    this.onRecordLoss,
    this.onSeedSmokeHistory,
  });

  final StatsDashboardSnapshot snapshot;
  final Future<void> Function()? onRecordWin;
  final Future<void> Function()? onRecordLoss;
  final Future<void> Function()? onSeedSmokeHistory;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardCard(
            title: 'Squad streaks',
            child: _StreaksBarChart(streaks: snapshot.memberStreaks),
          ),
          const SizedBox(height: 16),
          _DashboardCard(
            title: snapshot.winLossTitle,
            child: _WinLossPie(
              summary: snapshot.winLoss,
              emptyMessage: snapshot.winLossEmptyMessage,
              onRecordWin: onRecordWin,
              onRecordLoss: onRecordLoss,
              onSeedSmokeHistory: onSeedSmokeHistory,
            ),
          ),
          const SizedBox(height: 16),
          _DashboardCard(
            title: 'Average ratings',
            child: _RatingsRow(ratings: snapshot.ratings),
          ),
          const SizedBox(height: 16),
          _DashboardCard(
            title: 'Last 5 sessions',
            child: LastFiveRatedSessionsList(
              key: const Key('stats-last-five'),
              sessions: snapshot.lastFiveRatedSessions,
            ),
          ),
          const SizedBox(height: 16),
          _DashboardCard(
            title: 'Community',
            child: _CommunitySection(community: snapshot.community),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: neon.withValues(alpha: 0.35), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: neon,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StreaksBarChart extends StatelessWidget {
  const _StreaksBarChart({required this.streaks});

  final List<SquadMemberStreak> streaks;

  @override
  Widget build(BuildContext context) {
    if (streaks.isEmpty) {
      return const _EmptyHint(
        icon: Icons.local_fire_department_outlined,
        message: 'No squad members to chart yet',
      );
    }

    final neon = Theme.of(context).colorScheme.primary;
    final maxStreak = streaks.fold<int>(0, (m, s) => math.max(m, s.streak));
    final maxY = math.max(1, maxStreak).toDouble();
    final chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 64,
      streaks.length * 48.0,
    );

    return SizedBox(
      key: const Key('stats-streaks-chart'),
      height: 220,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartWidth,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY * 1.25,
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF14181F),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex < 0 || groupIndex >= streaks.length) {
                      return null;
                    }
                    final member = streaks[groupIndex];
                    return BarTooltipItem(
                      '${member.label}\n${member.streak}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: math.max(1, (maxY / 4).ceilToDouble()),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.white.withValues(alpha: 0.08),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: math.max(1, (maxY / 4).ceilToDouble()),
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value > maxY * 1.25) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= streaks.length) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          streaks[index].shortLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < streaks.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: streaks[i].streak.toDouble(),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        color: neon,
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY * 1.25,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WinLossPie extends StatelessWidget {
  const _WinLossPie({
    required this.summary,
    required this.emptyMessage,
    this.onRecordWin,
    this.onRecordLoss,
    this.onSeedSmokeHistory,
  });

  final WinLossSummary summary;
  final String emptyMessage;
  final Future<void> Function()? onRecordWin;
  final Future<void> Function()? onRecordLoss;
  final Future<void> Function()? onSeedSmokeHistory;

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) {
      return _EmptyHint(
        icon: Icons.pie_chart_outline,
        message: emptyMessage,
        actions: [
          if (onRecordWin != null)
            _EmptyActionButton(
              key: const Key('stats-record-win'),
              label: 'Record win',
              onPressed: onRecordWin!,
            ),
          if (onRecordLoss != null)
            _EmptyActionButton(
              key: const Key('stats-record-loss'),
              label: 'Record loss',
              onPressed: onRecordLoss!,
            ),
          if (onSeedSmokeHistory != null)
            _EmptyActionButton(
              key: const Key('stats-seed-match-history'),
              label: 'Seed 2–1 smoke record',
              onPressed: onSeedSmokeHistory!,
            ),
        ],
      );
    }

    const winColor = Color(0xFF2EE59D);
    const lossColor = Color(0xFFFF6B6B);
    const drawColor = Color(0xFFFFC857);

    final sections = <PieChartSectionData>[
      if (summary.wins > 0)
        PieChartSectionData(
          value: summary.wins.toDouble(),
          color: winColor,
          radius: 44,
          title: '${summary.wins}',
          titleStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      if (summary.losses > 0)
        PieChartSectionData(
          value: summary.losses.toDouble(),
          color: lossColor,
          radius: 44,
          title: '${summary.losses}',
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      if (summary.draws > 0)
        PieChartSectionData(
          value: summary.draws.toDouble(),
          color: drawColor,
          radius: 44,
          title: '${summary.draws}',
          titleStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
    ];

    return Column(
      key: const Key('stats-win-loss-chart'),
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 38,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            _LegendDot(color: winColor, label: 'Wins ${summary.wins}'),
            _LegendDot(color: lossColor, label: 'Losses ${summary.losses}'),
            if (summary.draws > 0)
              _LegendDot(color: drawColor, label: 'Draws ${summary.draws}'),
          ],
        ),
        if (summary.decided > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${(summary.winRate * 100).toStringAsFixed(0)}% win rate',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _RatingsRow extends StatelessWidget {
  const _RatingsRow({required this.ratings});

  final RatingSummary ratings;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('stats-ratings'),
      children: [
        Expanded(
          child: _RatingTile(
            label: 'Daily',
            value: RatingSummary.format(ratings.dailyAverage),
            sampleSize: ratings.dailySampleSize,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RatingTile(
            label: 'All-time',
            value: RatingSummary.format(ratings.allTimeAverage),
            sampleSize: ratings.allTimeSampleSize,
          ),
        ),
      ],
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({
    required this.label,
    required this.value,
    required this.sampleSize,
  });

  final String label;
  final String value;
  final int sampleSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sampleSize == 0
                ? 'No ratings yet'
                : '$sampleSize rating${sampleSize == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CommunitySection extends StatelessWidget {
  const _CommunitySection({required this.community});

  final CommunitySummary community;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('stats-community'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _CommunityChip(
              icon: Icons.report_outlined,
              label: 'Complaints',
              value: '${community.complaints}',
            ),
            _CommunityChip(
              icon: Icons.gavel_outlined,
              label: 'Bans',
              value: '${community.bans}',
            ),
            _CommunityChip(
              icon: Icons.group_outlined,
              label: 'Friends',
              value: '${community.friends}',
            ),
          ],
        ),
        if (community.gameAverages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'PER-GAME AVERAGE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final game in community.gameAverages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      game.gameName,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${game.average.toStringAsFixed(1)}★',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _CommunityChip extends StatelessWidget {
  const _CommunityChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.message,
    this.actions = const <Widget>[],
  });

  final IconData icon;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, color: Colors.white24, size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyActionButton extends StatelessWidget {
  const _EmptyActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        onPressed();
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.cyanAccent,
        side: const BorderSide(color: Colors.cyanAccent),
      ),
      child: Text(label),
    );
  }
}
