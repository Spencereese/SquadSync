import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/lobby_state.dart';

/// Compact empty / loading / error for Tonight, peacock/LFG chips, lock UI.
enum LobbySurfaceKind { tonight, peacock, lock }

enum LobbySurfacePhase { data, empty, loading, error }

const kLobbySurfaceRetryLabel = 'Retry';

const kTonightEmptyHint =
    "Pick a lobby to ping who's on, look for a squad, or invite.";

const kLobbySurfaceErrorHint = 'Check your connection and try again.';
const kLobbySurfaceOfflineCopy = "You're offline";

/// Arm's-length type on empty / error so copy reads from the couch.
const kLobbySurfaceTitleSize = 18.0;
const kLobbySurfaceBodySize = 15.0;
const kLobbySurfaceHintSize = 14.0;
const kLobbySurfaceCompactSize = 15.0;
const kLobbySurfaceActionMinHeight = 44.0;

/// Empty / error / offline for Tonight (and compact peacock/lock chips).
///
/// Loading only while a fetch is in flight with no error — never a hung
/// spinner. Offline or load failure is error + Retry, not empty.
LobbySurfacePhase resolveLobbySurfacePhase({
  required bool isLoading,
  Object? error,
  bool isEmpty = false,
  bool isOffline = false,
}) {
  if (isLoading && error == null && !isOffline) {
    return LobbySurfacePhase.loading;
  }
  if (error != null || isOffline) return LobbySurfacePhase.error;
  if (isEmpty) return LobbySurfacePhase.empty;
  return LobbySurfacePhase.data;
}

/// Tonight has nothing to act on when no selected / current lobby id.
bool tonightLobbyMissing(LobbyState? state) {
  final id = state?.selectedLobbyId ?? state?.currentLobby?.id;
  return id == null || id.isEmpty;
}

bool lobbySurfaceIsOfflineError(Object? error) {
  if (error == null) return false;
  final text = error.toString().toLowerCase();
  return text.contains('socket') ||
      text.contains('offline') ||
      text.contains('network') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('clientexception');
}

/// Cached lobby stays data (Tonight buttons still work). Missing lobby +
/// offline / load fail is error, not empty.
LobbySurfacePhase lobbySurfacePhaseFromAsync(
  AsyncValue<LobbyState> value, {
  bool Function(LobbyState state)? isEmpty,
  bool isOffline = false,
}) {
  final error = lobbyAsyncError(value);
  final offline = isOffline || lobbySurfaceIsOfflineError(error);
  final state = value.valueOrNull;
  final missing = state == null || (isEmpty?.call(state) ?? false);
  if (!missing) return LobbySurfacePhase.data;
  if (lobbyAsyncIsLoading(value) && error == null && !offline) {
    return LobbySurfacePhase.loading;
  }
  if (error != null || offline) return LobbySurfacePhase.error;
  return LobbySurfacePhase.empty;
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

Key lobbySurfaceRetryKey(LobbySurfaceKind kind) {
  switch (kind) {
    case LobbySurfaceKind.tonight:
      return const Key('tonight-retry');
    case LobbySurfaceKind.peacock:
      return const Key('peacock-chip-retry');
    case LobbySurfaceKind.lock:
      return const Key('lock-retry');
  }
}

Key lobbySurfaceEmptyActionKey(LobbySurfaceKind kind) {
  switch (kind) {
    case LobbySurfaceKind.tonight:
      return const Key('tonight-empty-cta');
    case LobbySurfaceKind.peacock:
      return const Key('peacock-chip-empty-cta');
    case LobbySurfaceKind.lock:
      return const Key('lock-empty-cta');
  }
}

Key lobbySurfaceHintKey(LobbySurfaceKind kind, LobbySurfacePhase phase) {
  switch (kind) {
    case LobbySurfaceKind.tonight:
      return phase == LobbySurfacePhase.error
          ? const Key('tonight-error-hint')
          : const Key('tonight-empty-hint');
    case LobbySurfaceKind.peacock:
      return phase == LobbySurfacePhase.error
          ? const Key('peacock-chip-error-hint')
          : const Key('peacock-chip-empty-hint');
    case LobbySurfaceKind.lock:
      return phase == LobbySurfacePhase.error
          ? const Key('lock-error-hint')
          : const Key('lock-empty-hint');
  }
}

Key lobbySurfaceDetailKey(LobbySurfaceKind kind) {
  switch (kind) {
    case LobbySurfaceKind.tonight:
      return const Key('tonight-error-detail');
    case LobbySurfaceKind.peacock:
      return const Key('peacock-chip-error-detail');
    case LobbySurfaceKind.lock:
      return const Key('lock-error-detail');
  }
}

String lobbySurfaceMessage(
  LobbySurfaceKind kind,
  LobbySurfacePhase phase, {
  bool isOffline = false,
}) {
  if (phase == LobbySurfacePhase.error && isOffline) {
    return kLobbySurfaceOfflineCopy;
  }
  switch (kind) {
    case LobbySurfaceKind.tonight:
      switch (phase) {
        case LobbySurfacePhase.empty:
          return 'No lobby tonight';
        case LobbySurfacePhase.loading:
          return 'Loading tonight...';
        case LobbySurfacePhase.error:
          return "Couldn't load tonight";
        case LobbySurfacePhase.data:
          return 'Tonight';
      }
    case LobbySurfaceKind.peacock:
      switch (phase) {
        case LobbySurfacePhase.empty:
          return 'Idle';
        case LobbySurfacePhase.loading:
          return 'Loading seat...';
        case LobbySurfacePhase.error:
          return "Couldn't load seat";
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
          return "Couldn't load lock";
        case LobbySurfacePhase.data:
          return 'Locked';
      }
  }
}

String? lobbySurfaceHint(
  LobbySurfaceKind kind,
  LobbySurfacePhase phase, {
  bool isOffline = false,
}) {
  switch (phase) {
    case LobbySurfacePhase.empty:
      return kind == LobbySurfaceKind.tonight ? kTonightEmptyHint : null;
    case LobbySurfacePhase.error:
      return kLobbySurfaceErrorHint;
    case LobbySurfacePhase.loading:
    case LobbySurfacePhase.data:
      return null;
  }
}

String? lobbySurfaceErrorDetail(Object? error) {
  if (error == null) return null;
  final text = error.toString().trim();
  if (text.isEmpty) return null;
  const prefix = 'Exception: ';
  if (text.startsWith(prefix) && text.length > prefix.length) {
    return text.substring(prefix.length);
  }
  return text;
}

/// Compact status used by Tonight strip, peacock/LFG chips, and lock UI.
class LobbySurfaceFeedback extends StatelessWidget {
  const LobbySurfaceFeedback({
    super.key,
    required this.kind,
    required this.phase,
    this.error,
    this.isOffline = false,
    this.compact = false,
    this.message,
    this.hint,
    this.onRetry,
    this.onAction,
    this.actionLabel,
  });

  final LobbySurfaceKind kind;
  final LobbySurfacePhase phase;
  final Object? error;
  final bool isOffline;
  final bool compact;
  final String? message;
  final String? hint;
  final VoidCallback? onRetry;
  final VoidCallback? onAction;
  final String? actionLabel;

  VoidCallback? get _resolvedAction {
    if (phase == LobbySurfacePhase.error) return onRetry ?? onAction;
    if (phase == LobbySurfacePhase.empty) return onAction;
    return null;
  }

  String? get _resolvedActionLabel {
    if (_resolvedAction == null) return null;
    if (actionLabel != null && actionLabel!.isNotEmpty) return actionLabel;
    if (phase == LobbySurfacePhase.error) return kLobbySurfaceRetryLabel;
    return null;
  }

  Key? get _resolvedActionKey {
    if (_resolvedAction == null || _resolvedActionLabel == null) return null;
    if (phase == LobbySurfacePhase.error) return lobbySurfaceRetryKey(kind);
    if (phase == LobbySurfacePhase.empty) {
      return lobbySurfaceEmptyActionKey(kind);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offline = isOffline || lobbySurfaceIsOfflineError(error);
    final text =
        message ?? lobbySurfaceMessage(kind, phase, isOffline: offline);
    final resolvedHint =
        hint ?? lobbySurfaceHint(kind, phase, isOffline: offline);
    final detail = phase == LobbySurfacePhase.error && !offline
        ? lobbySurfaceErrorDetail(error)
        : null;
    final key = lobbySurfaceKey(kind, phase);
    if (phase == LobbySurfacePhase.loading) {
      if (compact) {
        return SizedBox(
          key: key,
          width: 22,
          height: 22,
          child: const CircularProgressIndicator(strokeWidth: 2.5),
        );
      }
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: kLobbySurfaceBodySize,
                  fontWeight: FontWeight.w600,
                ),
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
        color = theme.colorScheme.onSurface.withValues(alpha: 0.72);
        icon = Icons.hourglass_empty;
      case LobbySurfacePhase.loading:
      case LobbySurfacePhase.data:
        color = theme.colorScheme.onSurface;
        icon = null;
    }

    if (compact) {
      return _CompactFeedback(
        widgetKey: key,
        color: color,
        icon: icon,
        text: text,
        actionLabel: _resolvedActionLabel,
        actionKey: _resolvedActionKey,
        onAction: _resolvedAction,
      );
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 28, color: color),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontSize: kLobbySurfaceTitleSize,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (resolvedHint != null && resolvedHint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              resolvedHint,
              key: lobbySurfaceHintKey(kind, phase),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color.withValues(alpha: 0.85),
                fontSize: kLobbySurfaceHintSize,
                height: 1.3,
              ),
            ),
          ],
          if (detail != null && detail.isNotEmpty && detail != text) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              key: lobbySurfaceDetailKey(kind),
              style: theme.textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
          if (_resolvedAction != null && _resolvedActionLabel != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: _resolvedActionKey,
                onPressed: _resolvedAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  minimumSize: const Size(88, kLobbySurfaceActionMinHeight),
                  textStyle: const TextStyle(
                    fontSize: kLobbySurfaceBodySize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(_resolvedActionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactFeedback extends StatelessWidget {
  const _CompactFeedback({
    required this.widgetKey,
    required this.color,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final Key widgetKey;
  final Color color;
  final IconData? icon;
  final String text;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: kLobbySurfaceCompactSize,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    );
    final body = ConstrainedBox(
      constraints:
          const BoxConstraints(minHeight: kLobbySurfaceActionMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
            ],
            label,
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                actionLabel!,
                style: TextStyle(
                  color: color,
                  fontSize: kLobbySurfaceCompactSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: color.withValues(alpha: 0.45)),
    );

    if (onAction == null) {
      return Material(
        key: widgetKey,
        color: color.withValues(alpha: 0.12),
        shape: shape,
        child: body,
      );
    }

    return Material(
      key: widgetKey,
      color: color.withValues(alpha: 0.12),
      shape: shape,
      child: InkWell(
        key: actionKey,
        onTap: onAction,
        borderRadius: BorderRadius.circular(16),
        child: body,
      ),
    );
  }
}
