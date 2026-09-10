import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/deep_link_routes.dart';
import '../../core/notification_routes.dart';
import '../../domain/entities/lobby_state.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../services/auth_service_supabase.dart';
import '../../services/lobby_seat_status.dart';
import '../../widgets/lobby_surface_feedback.dart';

/// Title on the filled chat peacock card.
String peacockCardTitle({
  required String gameName,
  required int claimed,
  required int maxSpots,
}) =>
    'Your Active Lobby: $gameName - $claimed/$maxSpots spots';

/// Live chat peacock card. Empty / offline use [LobbySurfaceFeedback];
/// a filled card tap reuses [openPeacockCard] / [NotificationRoutes].
class ChatPeacockCardHost extends ConsumerWidget {
  const ChatPeacockCardHost({
    super.key,
    this.spotIndex,
    this.go,
  });

  /// Offered seat override. Live path falls back to the seat tracker.
  final int? spotIndex;
  final void Function(String location)? go;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lobbyAsync = ref.watch(ln.lobbyNotifierProvider);
    final error = lobbyAsyncError(lobbyAsync);
    final offline = lobbySurfaceIsOfflineError(error);
    final phase = lobbySurfacePhaseFromAsync(
      lobbyAsync,
      isEmpty: peacockCardMissing,
      isOffline: offline,
    );
    final state = lobbyAsync.valueOrNull;
    final snapshot = peacockCardSnapshot(state);
    return ChatPeacockCard(
      phase: phase,
      error: phase == LobbySurfacePhase.error ? error : null,
      isOffline: phase == LobbySurfacePhase.error && offline,
      lobbyId: snapshot.lobbyId,
      gameName: snapshot.gameName,
      claimed: snapshot.claimed,
      maxSpots: snapshot.maxSpots,
      spotIndex: spotIndex ?? _liveSpotIndex(state),
      onRetry: () => ref.invalidate(ln.lobbyNotifierProvider),
      go: go,
    );
  }
}

int? _liveSpotIndex(LobbyState? state) {
  if (state == null) return null;
  try {
    final uid = AuthServiceSupabase().currentUser?.id;
    return resolveLobbySeatStatusFromTrackers(
      userId: uid,
      lobbyState: state,
    )?.seatIndex;
  } catch (_) {
    return null;
  }
}

/// Presentational chat peacock card. Tap uses [openPeacockCard] — the
/// same lobby/session router as notification `peacock_assigned`.
class ChatPeacockCard extends StatelessWidget {
  const ChatPeacockCard({
    super.key,
    this.phase = LobbySurfacePhase.data,
    this.lobbyId,
    this.gameName,
    this.claimed = 0,
    this.maxSpots = 0,
    this.spotIndex,
    this.error,
    this.isOffline = false,
    this.onRetry,
    this.go,
  });

  final LobbySurfacePhase phase;
  final String? lobbyId;
  final String? gameName;
  final int claimed;
  final int maxSpots;
  final int? spotIndex;
  final Object? error;
  final bool isOffline;
  final VoidCallback? onRetry;
  final void Function(String location)? go;

  void _open(BuildContext context) {
    openPeacockCard(
      lobbyId: lobbyId,
      gameName: gameName,
      spotIndex: spotIndex,
      isOffline: isOffline || phase == LobbySurfacePhase.error,
      go: go ??
          NotificationRoutes.go ??
          (location) => GoRouter.of(context).go(location),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (phase != LobbySurfacePhase.data) {
      return LobbySurfaceFeedback(
        kind: LobbySurfaceKind.peacockCard,
        phase: phase,
        error: error,
        isOffline: isOffline,
        onRetry: onRetry,
      );
    }

    final name = gameName ?? 'Unknown Game';
    return GestureDetector(
      key: const Key('peacock-card'),
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.cyanAccent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.cyanAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                peacockCardTitle(
                  gameName: name,
                  claimed: claimed,
                  maxSpots: maxSpots,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
