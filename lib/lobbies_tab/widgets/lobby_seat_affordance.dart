import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../services/auth_service_supabase.dart';
import '../../services/lobby_seat_status.dart';
import '../../services/matchmaking_queue_machine.dart';
import '../../services/peacock_assignment_machine.dart';

/// Compact seated / peacock / lock mm:ss chip.
class LobbySeatStatusChip extends StatelessWidget {
  const LobbySeatStatusChip({super.key, required this.status});

  final LobbySeatStatus status;

  Color get _color {
    switch (status.chip) {
      case LobbySeatChipKind.seated:
        return Colors.greenAccent;
      case LobbySeatChipKind.peacock:
        return Colors.cyanAccent;
      case LobbySeatChipKind.lock:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Chip(
      key: const Key('lobby-seat-status-chip'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      backgroundColor: color.withValues(alpha: 0.2),
      label: Text(
        status.chipLabel,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Live chip: existing peacock + LFG trackers + lobby spots/timers.
class LobbySeatStatusChipHost extends ConsumerWidget {
  const LobbySeatStatusChipHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lobbyState = ref.watch(ln.lobbyNotifierProvider).valueOrNull;
    return ListenableBuilder(
      listenable: MatchmakingQueueTracker.instance,
      builder: (context, _) {
        final status = resolveLobbySeatStatusFromTrackers(
          userId: _currentUidOrNull(),
          lobbyState: lobbyState,
        );
        if (status == null) return const SizedBox.shrink();
        return LobbySeatStatusChip(status: status);
      },
    );
  }
}

/// Accept / Decline on an offered peacock / LFG seat.
class LobbySeatOfferBanner extends StatelessWidget {
  const LobbySeatOfferBanner({
    super.key,
    required this.status,
    required this.onAccept,
    required this.onDecline,
    this.isBusy = false,
  });

  final LobbySeatStatus status;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (!status.showOfferBanner) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      key: const Key('lobby-seat-offer-banner'),
      color: Colors.cyanAccent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                claimSeatCopy(status.seatIndex),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            TextButton(
              key: const Key('lobby-seat-offer-accept'),
              onPressed: isBusy ? null : onAccept,
              child: const Text('Accept'),
            ),
            TextButton(
              key: const Key('lobby-seat-offer-decline'),
              onPressed: isBusy ? null : onDecline,
              child: const Text('Decline'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offer banner wired to [LobbyNotifier.assignPeacockSpot] + LFG
/// [joinMatched] (handoff false) / [declineOfferedSeat].
class LobbySeatOfferBannerHost extends ConsumerStatefulWidget {
  const LobbySeatOfferBannerHost({super.key});

  @override
  ConsumerState<LobbySeatOfferBannerHost> createState() =>
      _LobbySeatOfferBannerHostState();
}

class _LobbySeatOfferBannerHostState
    extends ConsumerState<LobbySeatOfferBannerHost> {
  bool _busy = false;

  MatchmakingQueueTracker get _lfg => MatchmakingQueueTracker.instance;

  Future<void> _accept(LobbySeatStatus status) async {
    final uid = _currentUidOrNull();
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final entry = _lfg.stateFor(uid);
      final peacock = PeacockAssignmentTracker.instance.stateFor(uid);
      final lobbyState = ref.read(ln.lobbyNotifierProvider).valueOrNull;
      final lobbyId = entry.lobbyId ??
          peacock.lobbyId ??
          lobbyState?.selectedLobbyId ??
          lobbyState?.currentLobby?.id;
      int? claimed;
      var handedOff = false;
      if (lobbyId != null && lobbyId.isNotEmpty) {
        claimed = await ref
            .read(ln.lobbyNotifierProvider.notifier)
            .assignPeacockSpot(
              userId: uid,
              lobbyId: lobbyId,
              gameName: entry.gameName ??
                  peacock.gameName ??
                  lobbyState?.currentGame?['name'] as String?,
              notificationId: entry.notificationId ?? peacock.notificationId,
              spotIndex: status.seatIndex,
            );
        handedOff = true;
      }
      if (entry.phase == MatchmakingQueuePhase.matched) {
        _lfg.joinMatched(uid, handoffToPeacock: false);
        await _lfg.persistCurrent(uid);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lfgJoinSnackbarMessage(
              claimedSpot: claimed,
              handedOff: handedOff,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept seat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _decline() {
    final uid = _currentUidOrNull();
    if (uid == null) return;
    declineOfferedSeat(
      userId: uid,
      lfg: _lfg,
      expirePeacock: (id) => ref
          .read(ln.lobbyNotifierProvider.notifier)
          .expirePeacockAssignment(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lobbyState = ref.watch(ln.lobbyNotifierProvider).valueOrNull;
    return ListenableBuilder(
      listenable: _lfg,
      builder: (context, _) {
        final status = resolveLobbySeatStatusFromTrackers(
          userId: _currentUidOrNull(),
          lobbyState: lobbyState,
        );
        if (status == null || !status.showOfferBanner) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: LobbySeatOfferBanner(
            status: status,
            isBusy: _busy,
            onAccept: () => _accept(status),
            onDecline: _decline,
          ),
        );
      },
    );
  }
}

/// Pulse the offered spot so a friend can find their seat.
class OfferedSpotPulse extends StatelessWidget {
  const OfferedSpotPulse({
    super.key,
    required this.pulse,
    required this.child,
  });

  final bool pulse;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!pulse) return child;
    return KeyedSubtree(
      key: const Key('offered-spot-pulse'),
      child: child
          .animate(onPlay: (controller) => controller.repeat())
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.03, 1.03),
            duration: const Duration(milliseconds: 900),
          )
          .then()
          .scale(
            begin: const Offset(1.03, 1.03),
            end: const Offset(1.0, 1.0),
            duration: const Duration(milliseconds: 900),
          ),
    );
  }
}

/// Ready toggle / Locked badge on a seated spot.
class SeatedSpotReadyAffordance extends StatelessWidget {
  const SeatedSpotReadyAffordance({
    super.key,
    required this.isReady,
    required this.isLocked,
    this.isOwnSeat = true,
    this.onToggle,
  });

  final bool isReady;
  final bool isLocked;
  final bool isOwnSeat;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    if (isLocked) {
      return Chip(
        key: const Key('seated-spot-locked-badge'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        backgroundColor: Colors.amberAccent.withValues(alpha: 0.2),
        label: const Text(
          'Locked',
          style: TextStyle(
            color: Colors.amberAccent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (!isOwnSeat) {
      if (!isReady) return const SizedBox.shrink();
      return Chip(
        key: const Key('seated-spot-ready-badge'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
        label: const Text(
          'Ready',
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isReady
              ? const [Colors.greenAccent, Colors.green]
              : const [Colors.tealAccent, Colors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isReady ? Colors.greenAccent : Colors.tealAccent)
                .withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        key: const Key('seated-spot-ready-button'),
        onPressed: onToggle,
        icon: Icon(
          isReady ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
        ),
        label: const Text('Ready'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

String? _currentUidOrNull() {
  try {
    return AuthServiceSupabase().currentUser?.id;
  } catch (_) {
    return null;
  }
}
