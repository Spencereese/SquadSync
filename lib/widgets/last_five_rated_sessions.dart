import 'package:flutter/material.dart';
import 'package:squad_sync/services/session_rating_machine.dart';

/// Last-5 rated nights from `match_history.notes`. Used on You and Stats.
class LastFiveRatedSessionsList extends StatelessWidget {
  const LastFiveRatedSessionsList({
    super.key,
    required this.sessions,
    this.emptyMessage = 'No rated sessions yet',
  });

  final List<SessionRatingState> sessions;
  final String emptyMessage;

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
            child: Text(
              lastFiveRatedSessionLabel(sessions[i]),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// You (Profile) last-5 block. [sessions] come from [statsDashboardProvider].
class YouLastFiveRatedSessions extends StatelessWidget {
  const YouLastFiveRatedSessions({super.key, required this.sessions});

  final List<SessionRatingState> sessions;

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
          LastFiveRatedSessionsList(sessions: sessions),
        ],
      ),
    );
  }
}
