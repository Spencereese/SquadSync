import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/session/data/session_repository.dart';
import 'package:squadsync/features/session/domain/session_ics.dart';
import 'package:squadsync/features/session/domain/squad_session.dart';

/// Upcoming sessions on Who's on. One column, no nested scroll.
class SessionList extends ConsumerStatefulWidget {
  const SessionList({
    required this.squadId,
    required this.meId,
    required this.ownerId,
    required this.onCallSpot,
    super.key,
  });

  final String squadId;
  final String meId;
  final String ownerId;
  final ValueChanged<String> onCallSpot;

  @override
  ConsumerState<SessionList> createState() => _SessionListState();
}

class _SessionListState extends ConsumerState<SessionList> {
  SessionBoard _board = SessionBoard.notEnabled;
  String? _error;
  StreamSubscription<void>? _live;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_open()));
  }

  @override
  void dispose() {
    final live = _live;
    _live = null;
    if (live != null) unawaited(live.cancel());
    super.dispose();
  }

  Future<void> _open() async {
    _live = ref
        .read(sessionRepositoryProvider)
        .watch(squadId: widget.squadId)
        .listen((_) => unawaited(_load()));
    await _load();
  }

  Future<void> _load() async {
    try {
      final board = await ref
          .read(sessionRepositoryProvider)
          .load(squadId: widget.squadId);
      if (!mounted) return;
      setState(() {
        _board = board;
        _error = null;
      });
    } on RepositoryFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_board.enabled) {
      return const Text(
        'Sessions are not set up yet.',
        key: Key('sessions-not-set-up'),
      );
    }
    final clock = ref.watch(squadClockProvider).now();
    final offset = ref.watch(localOffsetProvider);
    final upcoming = [
      for (final session in _board.sessions)
        if (sessionIsUpcoming(session, clock)) session,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) Text(_error!, key: const Key('session-error')),
        if (upcoming.isEmpty)
          const Text('No sessions scheduled.', key: Key('sessions-empty')),
        for (final session in upcoming)
          _card(session, clock: clock, offset: offset),
        TextButton(
          key: const Key('session-schedule'),
          onPressed: () => unawaited(_schedule(clock, offset)),
          child: const Text('Schedule a session'),
        ),
      ],
    );
  }

  Widget _card(
    SquadSession session, {
    required DateTime clock,
    required Duration offset,
  }) {
    final canChange =
        widget.meId == session.creatorId || widget.meId == widget.ownerId;
    final summary = sessionSummary(session, clock: clock, localOffset: offset);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary, key: Key('session-summary-${session.id}')),
          if (session.note != null) Text(session.note!),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _rsvp(session, SessionAnswer.rsvpIn, 'In'),
              _rsvp(session, SessionAnswer.maybe, 'Maybe'),
              _rsvp(session, SessionAnswer.out, 'Out'),
              _button(
                'Add to calendar',
                Key('session-calendar-${session.id}'),
                () => unawaited(_calendar(session)),
              ),
              if (sessionCanCallSpot(session, clock))
                _button(
                  'Call the spot now',
                  Key('session-call-${session.id}'),
                  () => widget.onCallSpot(session.game),
                ),
              if (canChange)
                _button(
                  'Edit',
                  Key('session-edit-${session.id}'),
                  () => unawaited(_edit(session, offset)),
                ),
              if (canChange)
                _button(
                  'Cancel session',
                  Key('session-cancel-${session.id}'),
                  () => unawaited(_cancel(session)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rsvp(SquadSession session, SessionAnswer answer, String label) {
    final selected = session.answerOf(widget.meId, answer);
    return _button(
      label,
      Key('session-${label.toLowerCase()}-${session.id}'),
      () => unawaited(_answer(session, answer)),
      selected: selected,
    );
  }

  Widget _button(
    String label,
    Key key,
    VoidCallback onPressed, {
    bool selected = false,
  }) {
    return FilledButton.tonal(
      key: key,
      style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
      onPressed: selected ? null : onPressed,
      child: Text(label),
    );
  }

  Future<void> _schedule(DateTime clock, Duration offset) async {
    final draft = await _ask(
      title: 'Schedule a session',
      startsAt: defaultSessionStart(clock, offset),
      clock: clock,
      offset: offset,
    );
    if (draft == null || !mounted) return;
    try {
      await ref
          .read(sessionRepositoryProvider)
          .create(
            squadId: widget.squadId,
            game: draft.game,
            startsAt: draft.startsAt,
            duration: draft.duration,
            note: draft.note,
          );
      await _load();
    } on SessionNotEnabled {
      if (!mounted) return;
      setState(() => _board = SessionBoard.notEnabled);
    } on RepositoryFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _edit(SquadSession session, Duration offset) async {
    final draft = await _ask(
      title: 'Edit this session',
      startsAt: session.startsAt,
      clock: ref.read(squadClockProvider).now(),
      offset: offset,
      game: session.game,
      note: session.note ?? '',
      minutes: session.duration?.inMinutes.toString() ?? '',
      confirm: 'Save these changes?',
    );
    if (draft == null || !mounted) return;
    try {
      await ref
          .read(sessionRepositoryProvider)
          .update(
            sessionId: session.id,
            game: draft.game,
            startsAt: draft.startsAt,
            duration: draft.duration,
            note: draft.note,
          );
      await _load();
    } on RepositoryFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _cancel(SquadSession session) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this session?'),
        content: const Text('People will no longer see it as upcoming.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('session-cancel-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel session'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref.read(sessionRepositoryProvider).cancel(sessionId: session.id);
      await _load();
    } on RepositoryFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _answer(SquadSession session, SessionAnswer answer) async {
    try {
      await ref
          .read(sessionRepositoryProvider)
          .rsvp(sessionId: session.id, answer: answer);
      await _load();
    } on RepositoryFailure catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _calendar(SquadSession session) async {
    await ref
        .read(calendarExportProvider)
        .shareIcs(filename: 'squad-session.ics', body: sessionIcs(session));
  }

  Future<_Draft?> _ask({
    required String title,
    required DateTime startsAt,
    required DateTime clock,
    required Duration offset,
    String game = '',
    String note = '',
    String minutes = '',
    String? confirm,
  }) {
    return showDialog<_Draft>(
      context: context,
      builder: (context) => _SessionDialog(
        title: title,
        startsAt: startsAt,
        clock: clock,
        offset: offset,
        game: game,
        note: note,
        minutes: minutes,
        confirm: confirm,
      ),
    );
  }
}

class _Draft {
  const _Draft({
    required this.game,
    required this.startsAt,
    this.duration,
    this.note,
  });

  final String game;
  final DateTime startsAt;
  final Duration? duration;
  final String? note;
}

class _SessionDialog extends StatefulWidget {
  const _SessionDialog({
    required this.title,
    required this.startsAt,
    required this.clock,
    required this.offset,
    required this.game,
    required this.note,
    required this.minutes,
    this.confirm,
  });

  final String title;
  final DateTime startsAt;
  final DateTime clock;
  final Duration offset;
  final String game;
  final String note;
  final String minutes;
  final String? confirm;

  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  late final TextEditingController _game;
  late final TextEditingController _note;
  late final TextEditingController _minutes;
  late DateTime _startsAt;

  @override
  void initState() {
    super.initState();
    _game = TextEditingController(text: widget.game);
    _note = TextEditingController(text: widget.note);
    _minutes = TextEditingController(text: widget.minutes);
    _startsAt = widget.startsAt;
  }

  @override
  void dispose() {
    _game.dispose();
    _note.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final when = sessionWhen(
      _startsAt,
      clock: widget.clock,
      localOffset: widget.offset,
    );
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('session-game'),
            controller: _game,
            decoration: const InputDecoration(labelText: 'Game'),
          ),
          Text(when, key: const Key('session-when')),
          TextField(
            key: const Key('session-note'),
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note, optional'),
          ),
          TextField(
            key: const Key('session-duration'),
            controller: _minutes,
            decoration: const InputDecoration(labelText: 'Minutes, optional'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          key: const Key('session-save'),
          onPressed: () => unawaited(_save(context)),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    if (widget.confirm != null) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.confirm!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            TextButton(
              key: const Key('session-edit-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (yes != true || !context.mounted) return;
    }
    final minutes = int.tryParse(_minutes.text.trim());
    Navigator.pop(
      context,
      _Draft(
        game: _game.text,
        startsAt: _startsAt,
        duration: minutes == null ? null : Duration(minutes: minutes),
        note: _note.text,
      ),
    );
  }
}
