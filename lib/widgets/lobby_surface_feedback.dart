import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/lobby_state.dart';

/// Compact empty / loading / error for Tonight, peacock/LFG chips, lock UI.
enum LobbySurfaceKind { tonight, peacock, lock }

enum LobbySurfacePhase { data, empty, loading, error }

/// Map existing [AsyncValue] + empty predicate. No new fetch.
LobbySurfacePhase resolveLobbySurfacePhase({
  required bool isLoading,
  Object? error,
  bool isEmpty = false,
}) {
  if (isLoading) return LobbySurfacePhase.loading;
  if (error != null) return LobbySurfacePhase.error;
  if (isEmpty) return LobbySurfacePhase.empty;
  return LobbySurfacePhase.data;
}

/// Tonight has nothing to act on when no selected / current lobby id.
bool tonightLobbyMissing(LobbyState? state) {
  final id = state?.selectedLobbyId ?? state?.currentLobby?.id;
  return id == null || id.isEmpty;
}

LobbySurfacePhase lobbySurfacePhaseFromAsync(
  AsyncValue<LobbyState> value, {
  bool Function(LobbyState state)? isEmpty,
}) {
  if (lobbyAsyncIsLoading(value)) return LobbySurfacePhase.loading;
  if (value.hasError) return LobbySurfacePhase.error;
  final state = value.valueOrNull;
  if (state == null) return LobbySurfacePhase.empty;
  return (isEmpty?.call(state) ?? false)
      ? LobbySurfacePhase.empty
      : LobbySurfacePhase.data;
}

Object? lobbyAsyncError(AsyncValue<dynamic> value) =>
    value.hasError ? value.error : null;

bool lobbyAsyncIsLoading(AsyncValue<dynamic> value) =>
    value.isLoading && value.valueOrNull == null;

Key lobbySurfaceKey(LobbySurfaceKind kind, LobbySurfacePhase phase) {
  switch (kind) {
    case LobbySurfaceKind.tonight:
      switch (phase) {
        case LobbySurfacePhase.empty:
          return const Key('tonight-empty');
        case LobbySurfacePhase.loading:
          return const Key('tonight-loading');
        case LobbySurfacePhase.error:
          return const Key('tonight-error');
        case LobbySurfacePhase.data:
          return const Key('tonight-actions');
      }
    case LobbySurfaceKind.peacock:
      switch (phase) {
        case LobbySurfacePhase.empty:
          return const Key('peacock-chip-empty');
        case LobbySurfacePhase.loading:
          return const Key('peacock-chip-loading');
        case LobbySurfacePhase.error:
          return const Key('peacock-chip-error');
        case LobbySurfacePhase.data:
          return const Key('lobby-seat-status-chip');
      }
    case LobbySurfaceKind.lock:
      switch (phase) {
        case LobbySurfacePhase.empty:
          return const Key('lock-empty');
        case LobbySurfacePhase.loading:
          return const Key('lock-loading');
        case LobbySurfacePhase.error:
          return const Key('lock-error');
        case LobbySurfacePhase.data:
          return const Key('seated-spot-locked-badge');
      }
  }
}

String lobbySurfaceMessage(
  LobbySurfaceKind kind,
  LobbySurfacePhase phase, {
  Object? error,
}) {
  switch (kind) {
    case LobbySurfaceKind.tonight:
      switch (phase) {
        case LobbySurfacePhase.empty:
          return 'No lobby tonight';
        case LobbySurfacePhase.loading:
          return 'Loading tonight...';
        case LobbySurfacePhase.error:
          return error == null
              ? "Couldn't load tonight"
              : "Couldn't load tonight: $error";
        case LobbySurfacePhase.data:
          return 'Tonight';
      }
    case LobbySurfaceKind.peacock:
      switch (phase) {
        case LobbySurfacePhase.empty:
          return 'idle';
        case LobbySurfacePhase.loading:
          return 'Loading seat...';
        case LobbySurfacePhase.error:
          return error == null
              ? "Couldn't load seat"
              : "Couldn't load seat: $error";
        case LobbySurfacePhase.data:
          return 'peacock';
      }
    case LobbySurfaceKind.lock:
      switch (phase) {
        case LobbySurfacePhase.empty:
          return 'Not locked';
        case LobbySurfacePhase.loading:
          return 'Loading lock...';
        case LobbySurfacePhase.error:
          return error == null
              ? "Couldn't load lock"
              : "Couldn't load lock: $error";
        case LobbySurfacePhase.data:
          return 'Locked';
      }
  }
}

/// Compact status used by Tonight strip, peacock/LFG chips, and lock UI.
class LobbySurfaceFeedback extends StatelessWidget {
  const LobbySurfaceFeedback({
    super.key,
    required this.kind,
    required this.phase,
    this.error,
    this.compact = false,
    this.message,
  });

  final LobbySurfaceKind kind;
  final LobbySurfacePhase phase;
  final Object? error;
  final bool compact;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = message ?? lobbySurfaceMessage(kind, phase, error: error);
    final key = lobbySurfaceKey(kind, phase);
    if (phase == LobbySurfacePhase.loading) {
      if (compact) {
        return SizedBox(
          key: key,
          width: 18,
          height: 18,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      }
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final Color color;
    IconData? icon;
    switch (phase) {
      case LobbySurfacePhase.error:
        color = theme.colorScheme.error;
        icon = Icons.error_outline;
      case LobbySurfacePhase.empty:
        color = theme.colorScheme.onSurface.withValues(alpha: 0.55);
        icon = Icons.hourglass_empty;
      case LobbySurfacePhase.loading:
      case LobbySurfacePhase.data:
        color = theme.colorScheme.onSurface;
        icon = null;
    }

    if (compact) {
      return Chip(
        key: key,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        backgroundColor: color.withValues(alpha: 0.12),
        avatar: icon == null ? null : Icon(icon, size: 14, color: color),
        label: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
