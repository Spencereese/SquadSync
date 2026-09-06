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
    case PresenceBadgeKind.offline:
      return Colors.blueGrey;
    case PresenceBadgeKind.stale:
      return Colors.amberAccent;
    case PresenceBadgeKind.reconnecting:
      return Colors.lightBlueAccent;
  }
}

SnackBar presenceReconnectSnackBar() {
  return const SnackBar(
    key: Key(kPresenceReconnectToastKey),
    content: Text(kPresenceReconnectingCopy),
    duration: Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
  );
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
    if (badges.isEmpty) {
      return const SizedBox.shrink(key: Key(kPresenceEmptyStripKey));
    }
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

  /// Widget tests leave a pending [Timer] if this is true. Production
  /// keeps it on so last-known Stale chips drop when the timeout elapses.
  static bool scheduleStaleCleanup = true;

  final String? userId;
  final bool compact;

  @override
  ConsumerState<PresenceBadgesHost> createState() => _PresenceBadgesHostState();
}

class _PresenceBadgesHostState extends ConsumerState<PresenceBadgesHost>
    with WidgetsBindingObserver {
  PresenceHealth? _lastHealth;
  DateTime? _staleSince;
  Timer? _staleTimer;
  bool _staleTimedOut = false;

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
    _staleTimer?.cancel();
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
    await refreshPresenceSources(force: true);
    if (mounted) setState(() {});
  }

  Future<void> _onStaleTimeout() async {
    _staleTimedOut = true;
    if (mounted) setState(() {});
    await refreshPresenceSources(force: true);
    if (mounted) setState(() {});
  }

  void _scheduleStaleCleanup(DateTime? staleSince) {
    if (!PresenceBadgesHost.scheduleStaleCleanup) return;
    if (_staleTimedOut) {
      _staleTimer?.cancel();
      _staleTimer = null;
      return;
    }
    if (staleSince == null) {
      _staleTimer?.cancel();
      _staleTimer = null;
      return;
    }
    if (_staleTimer != null) return;
    _staleTimer = Timer(kPresenceStaleTimeout, () {
      if (!mounted) return;
      unawaited(_onStaleTimeout());
    });
  }

  void _maybeReconnectToast({
    required PresenceHealth? previous,
    required PresenceHealth current,
    required bool lobbyReconnect,
    required bool stripEmpty,
  }) {
    if (stripEmpty) return;
    if (!shouldShowPresenceReconnectToast(
      previous: previous,
      current: current,
      lobbyReconnect: lobbyReconnect,
    )) {
      return;
    }
    if (!presenceReconnectToastGate.claim(now: DateTime.now().toUtc())) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(presenceReconnectSnackBar());
    });
  }

  @override
  Widget build(BuildContext context) {
    final lobbyAsync = ref.watch(ln.lobbyNotifierProvider);
    final lobbyState = lobbyAsync.valueOrNull;
    final isLoading = lobbyAsync.isLoading && lobbyState == null;
    final error = lobbyAsync.hasError ? lobbyAsync.error : null;
    return ListenableBuilder(
      listenable: Listenable.merge([
        MatchmakingQueueTracker.instance,
        availabilityOnStore,
      ]),
      builder: (context, _) {
        final now = DateTime.now().toUtc();
        if (_staleTimedOut) {
          _staleSince ??= now.subtract(kPresenceStaleTimeout);
        }
        final badges = resolvePresenceBadgesFromTrackers(
          userId: widget.userId,
          lobbyState: lobbyState,
          isLoading: isLoading,
          error: error,
          now: now,
          staleSince: _staleTimedOut
              ? now.subtract(kPresenceStaleTimeout)
              : _staleSince,
        );
        if (badges.health == PresenceHealth.stale) {
          _staleSince ??= now;
        } else if (badges.health == PresenceHealth.live ||
            badges.health == PresenceHealth.reconnecting) {
          _staleSince = null;
          _staleTimedOut = false;
        }
        final previous = _lastHealth;
        _lastHealth = badges.health;
        _scheduleStaleCleanup(_staleSince);
        _maybeReconnectToast(
          previous: previous,
          current: badges.health,
          lobbyReconnect: isLoading,
          stripEmpty: badges.isEmpty,
        );
        return PresenceBadgeRow(badges: badges, compact: widget.compact);
      },
    );
  }
}
