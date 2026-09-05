import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/deep_link_routes.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../services/auth_service_supabase.dart';
import '../../services/lobby_seat_status.dart';
import '../../services/matchmaking_queue_machine.dart';
import '../../services/peacock_assignment_machine.dart';
import '../../widgets/lobby_surface_feedback.dart';

/// Open-spot fill actions. Invite shares the existing lobby link;
/// Peacock claims the seat; Queue waits in the peacock queue.
enum EmptySpotCtaKind {
  invite,
  peacock,
  queue,
}

/// Peacock offer beats LFG / peacock queue; otherwise Invite.
EmptySpotCtaKind emptySpotCtaKindFor({
  bool peacockOffered = false,
  bool queuePending = false,
}) {
  if (peacockOffered) return EmptySpotCtaKind.peacock;
  if (queuePending) return EmptySpotCtaKind.queue;
  return EmptySpotCtaKind.invite;
}

/// LFG looking/matched or peacock queued counts as Queue on an open seat.
bool emptySpotQueuePending({
  MatchmakingQueuePhase? lfgPhase,
  PeacockAssignmentPhase? peacockPhase,
  bool peacockQueueOccupied = false,
}) {
  if (lfgPhase == MatchmakingQueuePhase.looking ||
      lfgPhase == MatchmakingQueuePhase.matched) {
    return true;
  }
  if (peacockPhase == PeacockAssignmentPhase.queued) return true;
  return peacockQueueOccupied;
}

bool emptySpotShowsCtas({
  required bool hasOccupant,
  required bool allowLateJoin,
}) =>
    !hasOccupant && allowLateJoin;

String emptySpotCtaLabel(EmptySpotCtaKind kind) {
  switch (kind) {
    case EmptySpotCtaKind.invite:
      return 'Invite';
    case EmptySpotCtaKind.peacock:
      return 'Peacock';
    case EmptySpotCtaKind.queue:
      return 'Queue';
  }
}

Key emptySpotCtaKey(EmptySpotCtaKind kind) {
  switch (kind) {
    case EmptySpotCtaKind.invite:
      return const Key('empty-spot-invite-button');
    case EmptySpotCtaKind.peacock:
      return const Key('empty-spot-peacock-button');
    case EmptySpotCtaKind.queue:
      return const Key('empty-spot-queue-button');
  }
}

/// Empty-spot Invite uses the same [shareLobbyLink] path as the lobby
/// header and Tonight Invite. Tests inject [copy] / [share].
Future<String> shareEmptySpotInvite({
  required String lobbyId,
  Future<void> Function(String link)? copy,
  Future<void> Function(String link)? share,
}) {
  return shareLobbyLink(lobbyId: lobbyId, copy: copy, share: share);
}

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

/// Peacock / LFG / lock chip with empty, loading, and error from existing
/// lobby [AsyncValue] + trackers. Idle (no seat) is an honest empty, not a
/// silent shrink.
class LobbySeatStatusChipSurface extends StatelessWidget {
  const LobbySeatStatusChipSurface({
    super.key,
    this.status,
    this.isLoading = false,
    this.error,
  });

  final LobbySeatStatus? status;
  final bool isLoading;
  final Object? error;

  LobbySurfacePhase get phase => resolveLobbySurfacePhase(
        isLoading: isLoading,
        error: error,
        isEmpty: status == null,
      );

  @override
  Widget build(BuildContext context) {
    final surfacePhase = phase;
    if (surfacePhase != LobbySurfacePhase.data || status == null) {
      return LobbySurfaceFeedback(
        kind: LobbySurfaceKind.peacock,
        phase: surfacePhase == LobbySurfacePhase.data
            ? LobbySurfacePhase.empty
            : surfacePhase,
        error: error,
        compact: true,
      );
    }
    return LobbySeatStatusChip(status: status!);
  }
}

/// Live chip: existing peacock + LFG trackers + lobby spots/timers.
class LobbySeatStatusChipHost extends ConsumerWidget {
  const LobbySeatStatusChipHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lobbyAsync = ref.watch(ln.lobbyNotifierProvider);
    return ListenableBuilder(
      listenable: MatchmakingQueueTracker.instance,
      builder: (context, _) {
        return lobbyAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const LobbySeatStatusChipSurface(isLoading: true),
          error: (error, _) => LobbySeatStatusChipSurface(error: error),
          data: (lobbyState) {
            final status = resolveLobbySeatStatusFromTrackers(
              userId: _currentUidOrNull(),
              lobbyState: lobbyState,
            );
            return LobbySeatStatusChipSurface(status: status);
          },
        );
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
///
/// Empty / loading / error come from existing lobby [AsyncValue] (or the
/// seated-not-ready case). Locked and Ready stay the live path.
class SeatedSpotReadyAffordance extends StatelessWidget {
  const SeatedSpotReadyAffordance({
    super.key,
    required this.isReady,
    required this.isLocked,
    this.isOwnSeat = true,
    this.onToggle,
    this.isLoading = false,
    this.error,
    this.timeoutRemaining,
    this.timeoutExpired = false,
  });

  final bool isReady;
  final bool isLocked;
  final bool isOwnSeat;
  final VoidCallback? onToggle;
  final bool isLoading;
  final Object? error;
  final Duration? timeoutRemaining;
  final bool timeoutExpired;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LobbySurfaceFeedback(
        kind: LobbySurfaceKind.lock,
        phase: LobbySurfacePhase.loading,
        compact: true,
      );
    }
    if (error != null) {
      return LobbySurfaceFeedback(
        kind: LobbySurfaceKind.lock,
        phase: LobbySurfacePhase.error,
        error: error,
        compact: true,
      );
    }
    if (timeoutExpired && !isLocked) {
      return Chip(
        key: const Key('seated-spot-timeout-chip'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
        label: const Text(
          'Timed out',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (isLocked) {
      if (isOwnSeat && onToggle != null) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.amberAccent, Colors.orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.amberAccent.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            key: const Key('seated-spot-unlock-button'),
            onPressed: onToggle,
            icon: const Icon(Icons.lock_open, size: 16),
            label: const Text('Unlock'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
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
      if (!isReady) {
        return const LobbySurfaceFeedback(
          kind: LobbySurfaceKind.lock,
          phase: LobbySurfacePhase.empty,
          compact: true,
        );
      }
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
        label: Text(_readyButtonLabel),
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

  String get _readyButtonLabel {
    final remaining = timeoutRemaining;
    if (isReady && remaining != null && remaining > Duration.zero) {
      return 'Ready ${formatLockMmSs(remaining)}';
    }
    return 'Ready';
  }
}

/// Peacock / lock timer readout. Expired and assigned labels follow
/// process_expired_timers; the client does not assign.
class LockTimerReadout extends StatelessWidget {
  const LockTimerReadout({
    super.key,
    required this.remaining,
    this.queueAssigned = false,
  });

  final Duration remaining;
  final bool queueAssigned;

  String get label =>
      formatTimerExpiryLabel(
        remaining: remaining,
        queueAssigned: queueAssigned,
      ) ??
      formatLockMmSs(remaining);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      key: const Key('lock-timer-readout'),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        fontSize: 12,
      ),
    );
  }
}

/// Invite / Peacock / Queue on an open seat. Primary kind is filled;
/// the other two stay outlined so all three labels stay readable.
class EmptySpotCtaBar extends StatelessWidget {
  const EmptySpotCtaBar({
    super.key,
    this.primary = EmptySpotCtaKind.invite,
    required this.onInvite,
    required this.onPeacock,
    required this.onQueue,
  });

  final EmptySpotCtaKind primary;
  final VoidCallback onInvite;
  final VoidCallback onPeacock;
  final VoidCallback onQueue;

  VoidCallback _onPressed(EmptySpotCtaKind kind) {
    switch (kind) {
      case EmptySpotCtaKind.invite:
        return onInvite;
      case EmptySpotCtaKind.peacock:
        return onPeacock;
      case EmptySpotCtaKind.queue:
        return onQueue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('empty-spot-cta-bar'),
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final kind in EmptySpotCtaKind.values)
          _EmptySpotCtaButton(
            kind: kind,
            emphasized: kind == primary,
            onPressed: _onPressed(kind),
          ),
      ],
    );
  }
}

class _EmptySpotCtaButton extends StatelessWidget {
  const _EmptySpotCtaButton({
    required this.kind,
    required this.emphasized,
    required this.onPressed,
  });

  final EmptySpotCtaKind kind;
  final bool emphasized;
  final VoidCallback onPressed;

  Color get _accent {
    switch (kind) {
      case EmptySpotCtaKind.invite:
        return Colors.tealAccent;
      case EmptySpotCtaKind.peacock:
        return Colors.cyanAccent;
      case EmptySpotCtaKind.queue:
        return Colors.orangeAccent;
    }
  }

  List<Color> get _gradient {
    switch (kind) {
      case EmptySpotCtaKind.invite:
        return const [Colors.tealAccent, Colors.teal];
      case EmptySpotCtaKind.peacock:
        return const [Colors.cyanAccent, Colors.cyan];
      case EmptySpotCtaKind.queue:
        return const [Colors.orangeAccent, Colors.orange];
    }
  }

  IconData get _icon {
    switch (kind) {
      case EmptySpotCtaKind.invite:
        return Icons.share;
      case EmptySpotCtaKind.peacock:
        return Icons.auto_awesome;
      case EmptySpotCtaKind.queue:
        return Icons.queue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final label = emptySpotCtaLabel(kind);
    final button = ElevatedButton.icon(
      key: emptySpotCtaKey(kind),
      onPressed: onPressed,
      icon: Icon(_icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: emphasized ? Colors.transparent : Colors.black54,
        foregroundColor: emphasized ? Colors.black : accent,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        side: emphasized
            ? BorderSide.none
            : BorderSide(color: accent.withValues(alpha: 0.85), width: 1.2),
      ),
    );
    return Semantics(
      button: true,
      label: label,
      child: emphasized
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: button,
            )
          : button,
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
