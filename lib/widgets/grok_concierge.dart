import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/lobby_state.dart';
import '../domain/entities/message.dart';
import '../presentation/notifiers/lobby_notifier.dart';
import '../presentation/notifiers/message_notifier.dart';
import '../services/grok_concierge.dart';
import '../services/grok_concierge_machine.dart';

/// Three Grok concierge commands. No free-chat field.
class GrokConciergeBlock extends StatelessWidget {
  const GrokConciergeBlock({
    super.key,
    required this.onWhosFree,
    required this.onSummarize,
    required this.onInvite,
    this.busyCommand,
    this.budgetExceeded = false,
  });

  final VoidCallback? onWhosFree;
  final VoidCallback? onSummarize;
  final VoidCallback? onInvite;
  final GrokConciergeCommand? busyCommand;
  final bool budgetExceeded;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('grok-concierge'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
          child: Text(
            'Grok',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (budgetExceeded)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              kGrokBudgetExceededCopy,
              key: Key('grok-concierge-budget'),
            ),
          ),
        _CommandButton(
          key: const Key('grok-concierge-whos-free'),
          label: kGrokConciergeWhosFreeLabel,
          busy: busyCommand == GrokConciergeCommand.whosFreeTonight,
          onPressed: busyCommand != null || budgetExceeded ? null : onWhosFree,
        ),
        const SizedBox(height: 12),
        _CommandButton(
          key: const Key('grok-concierge-summarize'),
          label: kGrokConciergeSummarizeLabel,
          busy: busyCommand == GrokConciergeCommand.summarizeLobbyChat,
          onPressed: busyCommand != null || budgetExceeded ? null : onSummarize,
        ),
        const SizedBox(height: 12),
        _CommandButton(
          key: const Key('grok-concierge-invite'),
          label: kGrokConciergeInviteLabel,
          busy: busyCommand == GrokConciergeCommand.draftPeacockInvite,
          onPressed: busyCommand != null || budgetExceeded ? null : onInvite,
        ),
      ],
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Live concierge on chat-info / lobby. Calls existing [GrokService] path.
class GrokConciergeSection extends ConsumerStatefulWidget {
  const GrokConciergeSection({
    super.key,
    this.squadId = '',
    this.runner,
    this.contextOverride,
  });

  final String squadId;
  final GrokConciergeRunner? runner;
  final GrokConciergeContext? contextOverride;

  @override
  ConsumerState<GrokConciergeSection> createState() =>
      _GrokConciergeSectionState();
}

class _GrokConciergeSectionState extends ConsumerState<GrokConciergeSection> {
  GrokConciergeCommand? _busy;
  bool _budgetExceeded = false;

  Future<void> _run(GrokConciergeCommand command) async {
    if (_busy != null || _budgetExceeded) return;
    setState(() => _busy = command);
    try {
      final runner = widget.runner ?? GrokConciergeRunner();
      final ctx = widget.contextOverride ?? _liveContext();
      final result = await runner.run(command: command, context: ctx);
      if (!mounted) return;
      setState(() {
        _busy = null;
        if (result.budgetExceeded) _budgetExceeded = true;
      });
      await _showResult(result);
    } catch (_) {
      if (mounted) setState(() => _busy = null);
    }
  }

  GrokConciergeContext _liveContext() {
    LobbyState? lobbyState;
    try {
      lobbyState = ref.read(lobbyNotifierProvider).valueOrNull;
    } catch (_) {
      lobbyState = null;
    }

    List<Message> messages = const [];
    final squadId = widget.squadId.trim();
    if (squadId.isNotEmpty) {
      try {
        messages = ref
            .read(messageNotifierProvider.notifier)
            .getMessagesForGroup(squadId);
      } catch (_) {
        messages = const [];
      }
    }

    final names = lobbyState?.memberDisplayNames ?? const <String, String>{};
    return buildConciergeContext(
      now: DateTime.now(),
      lobbyState: lobbyState,
      chatLines: chatLinesFromMessages(messages, displayNames: names),
    );
  }

  Future<void> _showResult(GrokConciergeResult result) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('grok-concierge-result'),
          title: Text(grokConciergeCommandLabel(result.command)),
          content: SingleChildScrollView(
            child: SelectableText(result.text),
          ),
          actions: [
            TextButton(
              key: const Key('grok-concierge-copy'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: result.text));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Copy'),
            ),
            TextButton(
              key: const Key('grok-concierge-close'),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GrokConciergeBlock(
      busyCommand: _busy,
      budgetExceeded: _budgetExceeded,
      onWhosFree: () => _run(GrokConciergeCommand.whosFreeTonight),
      onSummarize: () => _run(GrokConciergeCommand.summarizeLobbyChat),
      onInvite: () => _run(GrokConciergeCommand.draftPeacockInvite),
    );
  }
}
