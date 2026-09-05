import 'package:flutter/material.dart';

/// Arm's-length states on the lobby spot map.
///
/// Empty recedes (outline + OPEN). Filled sits mid (name + solid). Peacock
/// pops (cyan glow + PEACOCK). Visual hierarchy only — no new services.
enum LobbySpotMapKind {
  empty,
  filled,
  peacock,
}

/// Offered peacock seats stay peacock until occupied; occupied seats are filled.
LobbySpotMapKind lobbySpotMapKindFor({
  required bool hasOccupant,
  bool peacockOffered = false,
}) {
  if (peacockOffered && !hasOccupant) return LobbySpotMapKind.peacock;
  if (hasOccupant) return LobbySpotMapKind.filled;
  return LobbySpotMapKind.empty;
}

Key lobbySpotMapSeatKey(LobbySpotMapKind kind) {
  switch (kind) {
    case LobbySpotMapKind.empty:
      return const Key('spot-map-seat-empty');
    case LobbySpotMapKind.filled:
      return const Key('spot-map-seat-filled');
    case LobbySpotMapKind.peacock:
      return const Key('spot-map-seat-peacock');
  }
}

/// Presentational chrome for one lobby spot. Hosts existing trailing CTAs.
class LobbySpotMapSeat extends StatelessWidget {
  const LobbySpotMapSeat({
    super.key,
    required this.index,
    required this.kind,
    required this.statusLabel,
    this.displayName,
    this.timerLabel,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
  });

  final int index;
  final LobbySpotMapKind kind;
  final String statusLabel;
  final String? displayName;
  final String? timerLabel;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  int get seatNumber => index + 1;

  static Color accentFor(LobbySpotMapKind kind) {
    switch (kind) {
      case LobbySpotMapKind.empty:
        return Colors.tealAccent;
      case LobbySpotMapKind.filled:
        return Colors.greenAccent;
      case LobbySpotMapKind.peacock:
        return Colors.cyanAccent;
    }
  }

  static double borderWidthFor(LobbySpotMapKind kind) {
    switch (kind) {
      case LobbySpotMapKind.empty:
        return 1.5;
      case LobbySpotMapKind.filled:
        return 2.5;
      case LobbySpotMapKind.peacock:
        return 3.0;
    }
  }

  static Color fillFor(LobbySpotMapKind kind) {
    switch (kind) {
      case LobbySpotMapKind.empty:
        return Colors.white.withValues(alpha: 0.04);
      case LobbySpotMapKind.filled:
        return Colors.greenAccent.withValues(alpha: 0.12);
      case LobbySpotMapKind.peacock:
        return Colors.cyanAccent.withValues(alpha: 0.18);
    }
  }

  String get primaryLabel {
    switch (kind) {
      case LobbySpotMapKind.empty:
        return 'OPEN';
      case LobbySpotMapKind.filled:
        return (displayName != null && displayName!.isNotEmpty)
            ? displayName!
            : 'Spot $seatNumber';
      case LobbySpotMapKind.peacock:
        return 'PEACOCK';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentFor(kind);
    final fill = fillFor(kind);
    final borderWidth = borderWidthFor(kind);
    final statusColor = _statusColor(statusLabel, kind);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: kind == LobbySpotMapKind.peacock
              ? [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.45),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          key: lobbySpotMapSeatKey(kind),
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: kind == LobbySpotMapKind.empty
                  ? accent.withValues(alpha: 0.65)
                  : accent,
              width: borderWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Semantics(
              label: semanticLabel ??
                  'Spot $seatNumber: $primaryLabel, $statusLabel',
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    _leading(accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            primaryLabel,
                            key: const Key('spot-map-primary'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: kind == LobbySpotMapKind.filled
                                  ? Colors.white
                                  : accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: kind == LobbySpotMapKind.filled
                                  ? 0.2
                                  : 1.6,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Spot $seatNumber',
                            key: const Key('spot-map-seat-number'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _StatusChip(
                                label: statusLabel,
                                color: statusColor,
                              ),
                              if (timerLabel != null &&
                                  timerLabel!.isNotEmpty &&
                                  timerLabel != '00:00') ...[
                                const SizedBox(width: 8),
                                Text(
                                  timerLabel!,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading(Color accent) {
    final initial = displayName != null && displayName!.isNotEmpty
        ? displayName![0].toUpperCase()
        : '$seatNumber';
    if (kind == LobbySpotMapKind.empty) {
      return Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: accent.withValues(alpha: 0.9), width: 2),
        ),
        child: Text(
          '$seatNumber',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: accent,
      child: Text(
        kind == LobbySpotMapKind.peacock ? '$seatNumber' : initial,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }

  Color _statusColor(String status, LobbySpotMapKind kind) {
    switch (status) {
      case 'Ready':
        return Colors.greenAccent;
      case 'Locked':
        return Colors.amberAccent;
      case 'Calling':
        return Colors.orangeAccent;
      case 'Peacock':
        return Colors.cyanAccent;
      case 'Open':
        return Colors.tealAccent;
      case 'Occupied':
        return Colors.white;
      default:
        return accentFor(kind);
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('spot-map-status'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
