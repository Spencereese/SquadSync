import 'package:flutter/material.dart';

import '../core/chat_surface.dart';

export '../core/chat_surface.dart';

/// Empty / loading / error for ChatScreen and the shared chat list.
/// Error and empty never paint a spinner. Retry re-fetches via [onRetry].
class ChatSurfaceFeedback extends StatelessWidget {
  const ChatSurfaceFeedback({
    super.key,
    required this.kind,
    required this.phase,
    this.error,
    this.isOffline = false,
    this.message,
    this.hint,
    this.onRetry,
    this.onAction,
    this.actionLabel,
  });

  final ChatSurfaceKind kind;
  final ChatSurfacePhase phase;
  final Object? error;
  final bool isOffline;
  final String? message;
  final String? hint;
  final VoidCallback? onRetry;
  final VoidCallback? onAction;
  final String? actionLabel;

  VoidCallback? get _resolvedAction {
    if (phase == ChatSurfacePhase.error) return onRetry ?? onAction;
    if (phase == ChatSurfacePhase.empty) return onAction;
    return null;
  }

  String? get _resolvedActionLabel {
    if (_resolvedAction == null) return null;
    if (actionLabel != null && actionLabel!.isNotEmpty) return actionLabel;
    if (phase == ChatSurfacePhase.error) return kChatSurfaceRetryLabel;
    return null;
  }

  Key? get _resolvedActionKey {
    if (_resolvedAction == null || _resolvedActionLabel == null) return null;
    if (phase == ChatSurfacePhase.error) return chatSurfaceRetryKey(kind);
    if (phase == ChatSurfacePhase.empty) {
      return chatSurfaceEmptyActionKey(kind);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text =
        message ?? chatSurfaceMessage(kind, phase, isOffline: isOffline);
    final resolvedHint =
        hint ?? chatSurfaceHint(kind, phase, isOffline: isOffline);
    final detail =
        phase == ChatSurfacePhase.error ? chatSurfaceErrorDetail(error) : null;
    final key = chatSurfaceKey(kind, phase);

    if (phase == ChatSurfacePhase.loading) {
      return Center(
        child: Padding(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: kChatSurfaceBodySize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final Color color;
    IconData icon;
    switch (phase) {
      case ChatSurfacePhase.error:
        color = theme.colorScheme.error;
        icon = Icons.error_outline;
      case ChatSurfacePhase.empty:
        color = theme.colorScheme.onSurface.withValues(alpha: 0.72);
        icon = kind == ChatSurfaceKind.list
            ? Icons.chat_bubble_outline
            : Icons.forum_outlined;
      case ChatSurfacePhase.loading:
      case ChatSurfacePhase.data:
        color = theme.colorScheme.onSurface;
        icon = Icons.chat_bubble_outline;
    }

    return Center(
      child: Padding(
        key: key,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontSize: kChatSurfaceTitleSize,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            if (resolvedHint != null && resolvedHint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                resolvedHint,
                key: chatSurfaceHintKey(kind, phase),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color.withValues(alpha: 0.85),
                  fontSize: kChatSurfaceHintSize,
                  height: 1.3,
                ),
              ),
            ],
            if (detail != null && detail.isNotEmpty && detail != text) ...[
              const SizedBox(height: 6),
              Text(
                detail,
                key: chatSurfaceDetailKey(kind),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
            if (_resolvedAction != null && _resolvedActionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                key: _resolvedActionKey,
                onPressed: _resolvedAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  minimumSize: const Size(88, kChatSurfaceActionMinHeight),
                  textStyle: const TextStyle(
                    fontSize: kChatSurfaceBodySize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(_resolvedActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
