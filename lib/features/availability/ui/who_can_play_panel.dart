import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/availability/domain/who_can_play.dart';
import 'package:squadsync/features/availability/ui/availability_controller.dart';
import 'package:squadsync/features/availability/ui/availability_screen.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

/// Top of the squad home. One answer to who can play, plus the signed-in
/// person's own check-in. A game name is a label they typed, not a console.
class WhoCanPlayPanel extends ConsumerStatefulWidget {
  const WhoCanPlayPanel({
    required this.squad,
    required this.meId,
    this.demo = false,
    this.showDemoLine = true,
    this.showRest = false,
    this.onShowRest,
    super.key,
  });

  final Squad squad;
  final String meId;
  final bool demo;

  /// The chat banner already says this is a demo. The panel line is for the
  /// panel's own tests.
  final bool showDemoLine;

  /// Tests open the other sections. The home screen starts on the summary.
  final bool showRest;

  /// The chat screen hears this so the full board can take the page.
  final ValueChanged<bool>? onShowRest;

  @override
  ConsumerState<WhoCanPlayPanel> createState() => _WhoCanPlayPanelState();
}

class _WhoCanPlayPanelState extends ConsumerState<WhoCanPlayPanel> {
  final _game = TextEditingController();
  final _gameFocus = FocusNode();
  Timer? _tick;
  late bool _showRest = widget.showRest;

  bool get _rest => widget.onShowRest == null ? _showRest : widget.showRest;

  void _toggleRest() {
    final next = !_rest;
    final onShowRest = widget.onShowRest;
    if (onShowRest != null) {
      onShowRest(next);
      return;
    }
    setState(() => _showRest = next);
  }

  @override
  void initState() {
    super.initState();
    _gameFocus.addListener(_onGameFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final me = _member(widget.squad, widget.meId);
      if (me != null) _game.text = me.defaultGame;
      unawaited(
        ref
            .read(availabilityControllerProvider.notifier)
            .open(squad: widget.squad, meId: widget.meId),
      );
      final tick = ref.read(availabilityTickProvider);
      if (tick > Duration.zero) {
        _tick = Timer.periodic(tick, (_) {
          if (!mounted) return;
          ref.read(availabilityControllerProvider.notifier).reevaluate();
        });
      }
    });
  }

  void _onGameFocus() {
    if (_gameFocus.hasFocus) return;
    unawaited(_saveGame(_game.text));
  }

  @override
  void dispose() {
    _gameFocus.removeListener(_onGameFocus);
    _tick?.cancel();
    _gameFocus.dispose();
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(availabilityControllerProvider);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.demo && widget.showDemoLine)
              const Text(
                'Demo. Check-ins stay on this phone.',
                key: Key('who-demo'),
              ),
            const _Lead(),
            const SizedBox(height: 8),
            _Mine(
              game: _game,
              gameFocus: _gameFocus,
              showGame: _rest,
              saving: state.saving,
              effect: state.board?.person(widget.meId)?.effect,
              onAvailable: () => _save(const CheckInDraft.now()),
              onLater: _pickLater,
              onCant: () => _save(const CheckInDraft.unavailable()),
              onClear: _canClear(state.board?.person(widget.meId)?.effect)
                  ? _clear
                  : null,
              onGame: _saveGame,
            ),
            const SizedBox(height: 4),
            _Sections(showRest: _rest, onToggle: _toggleRest),
          ],
        ),
      ),
    );
  }

  void _save(CheckInDraft draft) {
    unawaited(_saveStatus(draft));
  }

  void _clear() {
    unawaited(ref.read(availabilityControllerProvider.notifier).clear());
  }

  Future<void> _saveStatus(CheckInDraft draft) async {
    await _saveGame(_game.text);
    if (!mounted) return;
    await ref.read(availabilityControllerProvider.notifier).save(draft);
  }

  Future<void> _pickLater() async {
    await _saveGame(_game.text);
    if (!mounted) return;
    final until = await showDialog<DateTime>(
      context: context,
      builder: (context) => const LaterTimeDialog(),
    );
    if (until == null || !mounted) return;
    await ref
        .read(availabilityControllerProvider.notifier)
        .save(CheckInDraft.later(until));
  }

  Future<void> _saveGame(String value) async {
    final me = _member(widget.squad, widget.meId);
    final game = value.trim();
    if (me == null || game.isEmpty || game == me.defaultGame) {
      if (game.isEmpty && mounted) {
        _game.text = me?.defaultGame ?? '';
      }
      return;
    }
    try {
      final saved = await ref
          .read(squadRepositoryProvider)
          .saveProfile(displayName: me.displayName, defaultGame: game);
      if (!mounted) return;
      ref.read(availabilityControllerProvider.notifier).noteMember(saved);
      await ref.read(squadChatControllerProvider.notifier).refreshFromRoster();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save the game. Nothing was changed.',
            key: Key('who-game-error'),
          ),
        ),
      );
    }
  }
}

class _Mine extends StatelessWidget {
  const _Mine({
    required this.game,
    required this.gameFocus,
    required this.showGame,
    required this.saving,
    required this.effect,
    required this.onAvailable,
    required this.onLater,
    required this.onCant,
    required this.onClear,
    required this.onGame,
  });

  final TextEditingController game;
  final FocusNode gameFocus;
  final bool showGame;
  final bool saving;
  final AvailabilityEffect? effect;
  final VoidCallback onAvailable;
  final VoidCallback onLater;
  final VoidCallback onCant;
  final VoidCallback? onClear;
  final ValueChanged<String> onGame;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusButton(
              label: 'Available',
              buttonKey: const Key('status-available'),
              selected: effect == AvailabilityEffect.availableNow,
              onPressed: saving ? null : onAvailable,
            ),
            _StatusButton(
              label: 'Maybe later',
              buttonKey: const Key('status-later'),
              selected: effect == AvailabilityEffect.availableLater,
              onPressed: saving ? null : onLater,
            ),
            _StatusButton(
              label: "Can't",
              buttonKey: const Key('status-cant'),
              selected: effect == AvailabilityEffect.unavailable,
              onPressed: saving ? null : onCant,
            ),
            if (onClear != null)
              _StatusButton(
                label: 'Not set',
                buttonKey: const Key('status-clear'),
                selected: false,
                onPressed: saving ? null : onClear,
              ),
          ],
        ),
        if (showGame) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('status-game'),
            controller: game,
            focusNode: gameFocus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Game',
              helperText: 'A label you type. Not a console reading.',
              helperMaxLines: 3,
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: onGame,
          ),
        ],
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.buttonKey,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final Key buttonKey;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(minimumSize: const Size(44, 44));
    final child = Text(selected ? '$label, selected' : label);
    return selected
        ? FilledButton(
            key: buttonKey,
            style: style,
            onPressed: onPressed,
            child: child,
          )
        : FilledButton.tonal(
            key: buttonKey,
            style: style,
            onPressed: onPressed,
            child: child,
          );
  }
}

class _Lead extends ConsumerWidget {
  const _Lead();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(availabilityControllerProvider);
    if (state.notEnabled) {
      return const Text(
        'Availability is not enabled on this project yet.',
        key: Key('who-disabled'),
      );
    }
    if (state.loading || (state.board == null && state.error == null)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(key: Key('who-loading')),
        ),
      );
    }
    final board = state.board;
    if (board == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.error ?? 'Could not load who can play.',
            key: const Key('who-error'),
          ),
          TextButton(
            key: const Key('who-retry'),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () {
              unawaited(
                ref.read(availabilityControllerProvider.notifier).retry(),
              );
            },
            child: const Text('Retry'),
          ),
        ],
      );
    }
    final who = WhoCanPlay.group(board: board, members: state.squad!.members);
    final faces = [...who.playingNow, ...who.available];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            who.summary,
            key: const Key('who-summary'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (faces.isNotEmpty)
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                key: const Key('who-avatars'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final row in faces)
                    Tooltip(
                      message: row.displayName,
                      child: CircleAvatar(
                        radius: 16,
                        child: Text(
                          row.displayName.isEmpty
                              ? '?'
                              : row.displayName.substring(0, 1),
                          textScaler: TextScaler.noScaling,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (state.stale)
          const Text(
            'Showing the last check-ins. The refresh failed.',
            key: Key('who-stale'),
          ),
        if (state.error != null)
          Text(state.error!, key: const Key('who-error')),
      ],
    );
  }
}

class _Sections extends ConsumerWidget {
  const _Sections({required this.showRest, required this.onToggle});

  final bool showRest;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(availabilityControllerProvider);
    final board = state.board;
    final squad = state.squad;
    if (board == null || squad == null) return const SizedBox.shrink();
    final offset = ref.watch(localOffsetProvider);
    final who = WhoCanPlay.group(board: board, members: squad.members);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (who.nobodyCheckedIn)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Nobody is checked in. Tap Available if you can play.',
              key: Key('who-empty'),
            ),
          ),
        _Section(
          title: 'Playing now',
          sectionKey: const Key('section-playing'),
          empty: 'Nobody else yet',
          rows: who.playingNow,
          offset: offset,
        ),
        _Section(
          title: 'Available',
          sectionKey: const Key('section-available'),
          empty: 'Nobody else yet',
          rows: who.available,
          offset: offset,
        ),
        if (showRest) ...[
          _Section(
            title: 'Maybe later',
            sectionKey: const Key('section-later'),
            empty: 'Nobody later',
            rows: who.maybeLater,
            offset: offset,
          ),
          _Section(
            title: 'Offline',
            sectionKey: const Key('section-offline'),
            empty: 'Nobody offline',
            rows: who.offline,
            offset: offset,
          ),
        ],
        TextButton(
          key: Key(showRest ? 'who-collapse' : 'who-expand'),
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: onToggle,
          child: Text(
            showRest
                ? 'Hide the rest'
                : 'Maybe later ${who.maybeLater.length} · Offline ${who.offline.length}',
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.sectionKey,
    required this.empty,
    required this.rows,
    required this.offset,
  });

  final String title;
  final Key sectionKey;
  final String empty;
  final List<WhoRow> rows;
  final Duration offset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        key: sectionKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (rows.isEmpty)
            Text(empty)
          else
            for (final row in rows)
              Semantics(
                label: whoSpokenLine(row, localOffset: offset),
                excludeSemantics: true,
                child: Text(
                  '${row.displayName} · ${whoStatusLine(row, localOffset: offset)}',
                  key: Key('who-${row.userId}'),
                ),
              ),
        ],
      ),
    );
  }
}

bool _canClear(AvailabilityEffect? effect) {
  return effect != null && effect != AvailabilityEffect.notCheckedIn;
}

Member? _member(Squad squad, String meId) {
  for (final member in squad.members) {
    if (member.id == meId) return member;
  }
  return null;
}
