import 'package:flutter/material.dart';
import 'package:squad_sync/services/session_rating_machine.dart';

/// End-session sheet: Vibes / Comms / Gunny / Wingman plus optional W/L
/// and notes. Skip still records the match.
///
/// [persist] keeps the sheet open on write fail so Submit becomes Retry.
Future<SessionRatingState> showSessionRatingDialog(
  BuildContext context, {
  required String lobbyId,
  String? raterUid,
  String? gameName,
  String? result,
  SessionRatingState? initial,
  Object? persistError,
  PersistSessionRating? persist,
}) async {
  final choice = await showDialog<SessionRatingState>(
    context: context,
    builder: (dialogContext) => SessionRatingDialog(
      lobbyId: lobbyId,
      raterUid: raterUid,
      gameName: gameName,
      result: result,
      initial: initial,
      persistError: persistError,
      persist: persist,
    ),
  );
  if (choice != null) return choice;
  return reduceSessionRating(
    current: initial ?? SessionRatingState.unrated,
    event: SessionRatingEvent.skip,
    lobbyId: lobbyId,
    raterUid: raterUid,
    gameName: gameName,
    result: result,
  );
}

/// Persist-fail sheet. Retry pops `true` so the caller re-runs the write.
Future<bool> showSessionRatingPersistErrorDialog(
  BuildContext context,
  SessionRatingPersistResult result,
) async {
  final retry = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final detail = sessionRatingErrorDetail(result.error);
      return AlertDialog(
        key: const Key('session-rating-persist-error'),
        title: const Text(kSessionRatingPersistErrorCopy),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              kSessionRatingPersistErrorHint,
              key: Key('session-rating-error-hint'),
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                key: const Key('session-rating-error-detail'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('session-rating-persist-dismiss'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            key: const Key('session-rating-retry'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(kSessionRatingPersistRetryLabel),
          ),
        ],
      );
    },
  );
  return retry == true;
}

SnackBar sessionRatingPersistSnackBar(
  String result,
  SessionRatingPersistResult persist, {
  VoidCallback? onRetry,
}) {
  final failed = persist.isFailed;
  return SnackBar(
    content: Text(
      sessionRatingPersistMessage(persist, matchResult: result),
      key: sessionRatingPersistFeedbackKey(persist.outcome),
    ),
    action: failed && onRetry != null
        ? SnackBarAction(
            key: const Key('session-rating-retry'),
            label: kSessionRatingPersistRetryLabel,
            onPressed: onRetry,
          )
        : null,
  );
}

void presentSessionRatingPersist(
  BuildContext context,
  String result,
  SessionRatingPersistResult persist, {
  VoidCallback? onRetry,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    sessionRatingPersistSnackBar(result, persist, onRetry: onRetry),
  );
}

class SessionRatingDialog extends StatefulWidget {
  const SessionRatingDialog({
    super.key,
    required this.lobbyId,
    this.raterUid,
    this.gameName,
    this.result,
    this.initial,
    this.persistError,
    this.persist,
  });

  final String lobbyId;
  final String? raterUid;
  final String? gameName;
  final String? result;
  final SessionRatingState? initial;
  final Object? persistError;
  final PersistSessionRating? persist;

  @override
  State<SessionRatingDialog> createState() => _SessionRatingDialogState();
}

class _SessionRatingDialogState extends State<SessionRatingDialog> {
  late final Map<String, int?> _ratings = {
    for (final label in kSessionRatingCategoryLabels) label: null,
  };
  final _notesController = TextEditingController();
  late String? _result = widget.result;
  Object? _persistError;
  bool _persisting = false;

  @override
  void initState() {
    super.initState();
    _persistError = widget.persistError;
    final initial = widget.initial;
    if (initial == null) return;
    _ratings['Vibes'] = initial.vibes;
    _ratings['Comms'] = initial.comms;
    _ratings['Gunny'] = initial.gunny;
    _ratings['Wingman'] = initial.wingman;
    _result = initial.result ?? widget.result;
    final comment = initial.comment?.trim();
    if (comment != null && comment.isNotEmpty) {
      _notesController.text = comment;
    }
  }

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
        clip: widget.initial?.clip,
        ratedAt: widget.initial?.ratedAt,
        matchId: widget.initial?.matchId,
      );

  String? get _trimmedNotes {
    final text = _notesController.text.trim();
    return text.isEmpty ? null : text;
  }

  bool get _canSubmit => _ratings.values.any(isValidSessionStars);

  SessionRatingState _ratedSnapshot() => reduceSessionRating(
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
        clip: widget.initial?.clip,
        ratedAt: widget.initial?.ratedAt,
        matchId: widget.initial?.matchId,
      );

  Future<void> _submit() async {
    if (!_canSubmit || _persisting) return;
    final rating = _ratedSnapshot();
    final persist = widget.persist;
    if (persist == null) {
      Navigator.of(context).pop(rating);
      return;
    }
    setState(() {
      _persisting = true;
      _persistError = null;
    });
    final result = await persist(rating);
    if (!mounted) return;
    if (result.isFailed) {
      setState(() {
        _persisting = false;
        _persistError = result.error;
      });
      return;
    }
    Navigator.of(context).pop(rating);
  }

  void _skip() {
    if (_persisting) return;
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
    final showEmpty = !_canSubmit && _persistError == null;
    final retrying = _persistError != null;
    return AlertDialog(
      key: const Key('session-rating-dialog'),
      title: const Text('Rate this session'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showEmpty) ...[
              const Text(
                kSessionRatingEmptyCopy,
                key: Key('session-rating-empty'),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                kSessionRatingEmptyHint,
                key: Key('session-rating-empty-hint'),
              ),
              const SizedBox(height: 8),
            ] else
              const Text('How was this squad session?'),
            if (_persistError != null) ...[
              const SizedBox(height: 8),
              Text(
                kSessionRatingPersistErrorCopy,
                key: const Key('session-rating-error'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                kSessionRatingPersistErrorHint,
                key: Key('session-rating-error-hint'),
              ),
              if (sessionRatingErrorDetail(_persistError).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  sessionRatingErrorDetail(_persistError),
                  key: const Key('session-rating-error-detail'),
                ),
              ],
              const SizedBox(height: 8),
            ],
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
          onPressed: _persisting ? null : _skip,
          child: const Text('Skip'),
        ),
        FilledButton(
          key: Key(retrying ? 'session-rating-retry' : 'session-rating-submit'),
          onPressed: _canSubmit && !_persisting ? _submit : null,
          child: Text(
            retrying
                ? kSessionRatingPersistRetryLabel
                : _persisting
                    ? 'Saving…'
                    : 'Submit',
          ),
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
