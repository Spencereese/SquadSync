import 'package:flutter/material.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:squad_sync/widgets/session_clip_playback.dart';

/// Last-5 rated nights from `match_history.notes`. Used on You and Stats.
class LastFiveRatedSessionsList extends StatelessWidget {
  const LastFiveRatedSessionsList({
    super.key,
    required this.sessions,
    this.emptyMessage = kLastFiveRatedEmptyCopy,
    this.emptyHint = kLastFiveRatedEmptyHint,
    this.errorMessage,
    this.errorDetail,
    this.onRetry,
    this.onOpenClip,
    this.isLoading = false,
  });

  final List<SessionRatingState> sessions;
  final String emptyMessage;
  final String emptyHint;
  final String? errorMessage;
  final String? errorDetail;
  final VoidCallback? onRetry;
  final bool isLoading;

  /// Defaults to [openSessionClipMedia] (existing video_player / url_launcher).
  final OpenSessionClip? onOpenClip;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _LastFiveStatus(
        key: Key('last-five-rated-loading'),
        icon: Icons.hourglass_empty,
        message: kLastFiveRatedLoadingCopy,
        showSpinner: true,
      );
    }
    if (errorMessage != null) {
      return _LastFiveStatus(
        key: const Key('last-five-rated-error'),
        icon: Icons.error_outline,
        message: errorMessage!,
        hint: errorDetail ?? kStatsLoadErrorBody,
        hintKey: const Key('last-five-rated-error-detail'),
        actionLabel: onRetry == null ? null : kStatsLoadErrorRetryLabel,
        actionKey: const Key('last-five-rated-retry'),
        onAction: onRetry,
      );
    }
    if (sessions.isEmpty) {
      return _LastFiveStatus(
        key: const Key('last-five-rated-empty'),
        icon: Icons.star_border,
        message: emptyMessage,
        hint: emptyHint,
        hintKey: const Key('last-five-rated-empty-hint'),
      );
    }
    return Column(
      key: const Key('last-five-rated-sessions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sessions.length; i++)
          Padding(
            key: Key('last-five-rated-row-$i'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _LastFiveRatedSessionRow(
              index: i,
              session: sessions[i],
              onOpenClip: onOpenClip,
            ),
          ),
      ],
    );
  }
}

class _LastFiveRatedSessionRow extends StatelessWidget {
  const _LastFiveRatedSessionRow({
    required this.index,
    required this.session,
    this.onOpenClip,
  });

  final int index;
  final SessionRatingState session;
  final OpenSessionClip? onOpenClip;

  @override
  Widget build(BuildContext context) {
    final categories = lastFiveRatedSessionCategoriesLabel(session);
    final notes = lastFiveRatedSessionNotesLabel(session);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lastFiveRatedSessionLabel(session),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (session.hasClip)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  canOpenSessionClip(session.clip)
                      ? Icons.play_circle_outline
                      : Icons.movie,
                  key: Key('last-five-rated-clip-$index'),
                  size: 16,
                  color: Colors.white54,
                ),
              ),
          ],
        ),
        if (categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              categories,
              key: Key('last-five-rated-cats-$index'),
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
            ),
          ),
        if (notes != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              notes,
              key: Key('last-five-rated-notes-$index'),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
    if (!session.hasClip) return body;
    return InkWell(
      key: Key('last-five-rated-open-$index'),
      onTap: () => _open(context),
      child: body,
    );
  }

  Future<void> _open(BuildContext context) async {
    final clip = session.clip;
    if (clip == null || !clip.isAttached) return;
    final opener = onOpenClip ?? openSessionClipMedia;
    final opened = await opener(context, clip);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: Key('session-clip-unavailable'),
        content: Text(kSessionClipUnavailableCopy),
      ),
    );
  }
}

/// You (Profile) last-5 block. [sessions] come from [statsDashboardProvider].
class YouLastFiveRatedSessions extends StatelessWidget {
  const YouLastFiveRatedSessions({
    super.key,
    required this.sessions,
    this.errorMessage,
    this.errorDetail,
    this.onRetry,
    this.onOpenClip,
    this.isLoading = false,
  });

  final List<SessionRatingState> sessions;
  final String? errorMessage;
  final String? errorDetail;
  final VoidCallback? onRetry;
  final OpenSessionClip? onOpenClip;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      key: const Key('you-last-five'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST 5 SESSIONS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          LastFiveRatedSessionsList(
            sessions: sessions,
            errorMessage: errorMessage,
            errorDetail: errorDetail,
            onRetry: onRetry,
            onOpenClip: onOpenClip,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

class _LastFiveStatus extends StatelessWidget {
  const _LastFiveStatus({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.hintKey,
    this.actionLabel,
    this.actionKey,
    this.onAction,
    this.showSpinner = false,
  });

  final IconData icon;
  final String message;
  final String? hint;
  final Key? hintKey;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          if (showSpinner)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.cyanAccent,
              ),
            )
          else
            Icon(icon, color: Colors.white38, size: 36),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (hint != null && hint!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              key: hintKey,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              key: actionKey,
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
                side: const BorderSide(color: Colors.cyanAccent),
                minimumSize: const Size(88, 44),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
