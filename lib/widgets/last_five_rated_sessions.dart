import 'package:flutter/material.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:squad_sync/widgets/session_clip_playback.dart';

/// Last-5 rated nights from `match_history.notes`. Used on You and Stats.
class LastFiveRatedSessionsList extends StatelessWidget {
  const LastFiveRatedSessionsList({
    super.key,
    required this.sessions,
    this.emptyMessage = 'No rated sessions yet',
    this.onOpenClip,
  });

  final List<SessionRatingState> sessions;
  final String emptyMessage;

  /// Defaults to [openSessionClipMedia] (existing video_player / url_launcher).
  final OpenSessionClip? onOpenClip;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          emptyMessage,
          key: const Key('last-five-rated-empty'),
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
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
    final row = Row(
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
    );
    if (!session.hasClip) return row;
    return InkWell(
      key: Key('last-five-rated-open-$index'),
      onTap: () => _open(context),
      child: row,
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
        content: Text('Clip media is unavailable'),
      ),
    );
  }
}

/// You (Profile) last-5 block. [sessions] come from [statsDashboardProvider].
class YouLastFiveRatedSessions extends StatelessWidget {
  const YouLastFiveRatedSessions({
    super.key,
    required this.sessions,
    this.onOpenClip,
  });

  final List<SessionRatingState> sessions;
  final OpenSessionClip? onOpenClip;

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
            onOpenClip: onOpenClip,
          ),
        ],
      ),
    );
  }
}
