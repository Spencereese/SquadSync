import 'package:flutter/material.dart';
import 'package:squad_sync/services/session_rating_machine.dart';

/// 1–5 star prompt on existing post-session surfaces (lobby Win/Loss,
/// stats Record win/loss). Skip still records the match.
Future<SessionRatingState> showSessionRatingDialog(
  BuildContext context, {
  required String lobbyId,
  String? raterUid,
  String? gameName,
  String? result,
}) async {
  final choice = await showDialog<SessionRatingState>(
    context: context,
    builder: (dialogContext) => SessionRatingDialog(
      lobbyId: lobbyId,
      raterUid: raterUid,
      gameName: gameName,
      result: result,
    ),
  );
  if (choice != null) return choice;
  return reduceSessionRating(
    current: SessionRatingState.unrated,
    event: SessionRatingEvent.skip,
    lobbyId: lobbyId,
    raterUid: raterUid,
    gameName: gameName,
    result: result,
  );
}

class SessionRatingDialog extends StatefulWidget {
  const SessionRatingDialog({
    super.key,
    required this.lobbyId,
    this.raterUid,
    this.gameName,
    this.result,
  });

  final String lobbyId;
  final String? raterUid;
  final String? gameName;
  final String? result;

  @override
  State<SessionRatingDialog> createState() => _SessionRatingDialogState();
}

class _SessionRatingDialogState extends State<SessionRatingDialog> {
  int? _stars;

  SessionRatingState _base() => SessionRatingState(
        lobbyId: widget.lobbyId,
        raterUid: widget.raterUid,
        gameName: widget.gameName,
        result: widget.result,
      );

  void _submit() {
    Navigator.of(context).pop(
      reduceSessionRating(
        current: _base(),
        event: SessionRatingEvent.rate,
        stars: _stars,
        lobbyId: widget.lobbyId,
        raterUid: widget.raterUid,
        gameName: widget.gameName,
        result: widget.result,
      ),
    );
  }

  void _skip() {
    Navigator.of(context).pop(
      reduceSessionRating(
        current: _base(),
        event: SessionRatingEvent.skip,
        lobbyId: widget.lobbyId,
        raterUid: widget.raterUid,
        gameName: widget.gameName,
        result: widget.result,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = isValidSessionStars(_stars);
    return AlertDialog(
      key: const Key('session-rating-dialog'),
      title: const Text('Rate this session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How was this squad session?'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: Key('session-rating-star-$i'),
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(
                    i <= (_stars ?? 0) ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('session-rating-skip'),
          onPressed: _skip,
          child: const Text('Skip'),
        ),
        FilledButton(
          key: const Key('session-rating-submit'),
          onPressed: canSubmit ? _submit : null,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
