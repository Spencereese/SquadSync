import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/notifiers/lobby_notifier.dart' as ln;
import '../services/availability_on.dart';
import '../services/matchmaking_queue_machine.dart';
import '../services/presence_badges.dart';

Color presenceBadgeColor(PresenceBadgeKind kind) {
  switch (kind) {
    case PresenceBadgeKind.on:
      return Colors.greenAccent;
    case PresenceBadgeKind.looking:
      return Colors.cyanAccent;
    case PresenceBadgeKind.inLobby:
      return Colors.orangeAccent;
  }
}

/// Compact On / Looking / In lobby chips. Pass [badges] from the helper.
class PresenceBadgeRow extends StatelessWidget {
  const PresenceBadgeRow({
    super.key,
    required this.badges,
    this.compact = false,
  });

  final PresenceBadges badges;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      key: const Key('presence-badges'),
      spacing: compact ? 3 : 6,
      runSpacing: compact ? 2 : 4,
      alignment: compact ? WrapAlignment.center : WrapAlignment.start,
      children: [
        for (final kind in badges.kinds) _chip(kind),
      ],
    );
  }

  Widget _chip(PresenceBadgeKind kind) {
    final color = presenceBadgeColor(kind);
    final fontSize = compact ? 8.0 : 11.0;
    return Container(
      key: Key(presenceBadgeKey(kind)),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 8,
        vertical: compact ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(compact ? 4 : 8),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
      ),
      child: Text(
        presenceBadgeLabel(kind),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Live glance badges: availability pings + LFG tracker + lobby membership.
class PresenceBadgesHost extends ConsumerStatefulWidget {
  const PresenceBadgesHost({
    super.key,
    required this.userId,
    this.compact = false,
  });

  final String? userId;
  final bool compact;

  @override
  ConsumerState<PresenceBadgesHost> createState() => _PresenceBadgesHostState();
}

class _PresenceBadgesHostState extends ConsumerState<PresenceBadgesHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    await refreshPresenceSources();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lobbyState = ref.watch(ln.lobbyNotifierProvider).valueOrNull;
    return ListenableBuilder(
      listenable: Listenable.merge([
        MatchmakingQueueTracker.instance,
        availabilityOnStore,
      ]),
      builder: (context, _) {
        final badges = resolvePresenceBadgesFromTrackers(
          userId: widget.userId,
          lobbyState: lobbyState,
        );
        if (badges.isEmpty) return const SizedBox.shrink();
        return PresenceBadgeRow(badges: badges, compact: widget.compact);
      },
    );
  }
}
