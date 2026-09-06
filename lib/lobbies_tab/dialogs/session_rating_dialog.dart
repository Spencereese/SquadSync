import 'package:flutter/material.dart';
import 'package:squad_sync/services/session_rating_machine.dart';

/// End-session sheet: Vibes / Comms / Gunny / Wingman plus optional W/L
/// and notes. Skip still records the match.
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
  final _ratings = <String, int?>{
    for (final label in kSessionRatingCategoryLabels) label: null,
  };
  final _notesController = TextEditingController();
  late String? _result = widget.result;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  SessionRatingState _base() => SessionRatingState(
        lobbyId: widget.lobbyId,
        raterUid: widget.raterUid,
        gameName: widget.gameName,
        result: _result,
        comment: _trimmedNotes,
      );

  String? get _trimmedNotes {
    final text = _notesController.text.trim();
    return text.isEmpty ? null : text;
  }

  bool get _canSubmit => _ratings.values.any(isValidSessionStars);

  void _submit() {
    Navigator.of(context).pop(
      reduceSessionRating(
        current: _base(),
        event: SessionRatingEvent.rate,
        vibes: _ratings['Vibes'],
        comms: _ratings['Comms'],
        gunny: _ratings['Gunny'],
        wingman: _ratings['Wingman'],
        lobbyId: widget.lobbyId,
        raterUid: widget.raterUid,
        gameName: widget.gameName,
        result: _result,
        comment: _trimmedNotes,
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
        result: _result,
        comment: _trimmedNotes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('session-rating-dialog'),
      title: const Text('Rate this session'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('How was this squad session?'),
            const SizedBox(height: 8),
            for (final label in kSessionRatingCategoryLabels)
              _CategoryRow(
                label: label,
                value: _ratings[label],
                onChanged: (stars) =>
                    setState(() => _ratings[label] = stars),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('session-rating-win'),
                  label: const Text('Win'),
                  selected: _result == 'win',
                  onSelected: (selected) => setState(
                    () => _result = selected ? 'win' : null,
                  ),
                ),
                ChoiceChip(
                  key: const Key('session-rating-loss'),
                  label: const Text('Loss'),
                  selected: _result == 'loss',
                  onSelected: (selected) => setState(
                    () => _result = selected ? 'loss' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('session-rating-notes'),
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Clutch, comms, callouts…',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('session-rating-skip'),
          onPressed: _skip,
          child: const Text('Skip'),
        ),
        FilledButton(
          key: const Key('session-rating-submit'),
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final slug = label.toLowerCase();
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: Key('session-rating-$slug-$i'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onChanged(i),
                  icon: Icon(
                    i <= (value ?? 0) ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
