import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/invite/data/code_share.dart';
import 'package:squadsync/features/invite/domain/invite_code.dart';
import 'package:squadsync/features/invite/ui/invite_controller.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({this.demo = false, super.key});

  final bool demo;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(inviteControllerProvider.notifier).load());
      final tick = ref.read(availabilityTickProvider);
      if (tick > Duration.zero) {
        _clock = Timer.periodic(tick, (_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inviteControllerProvider);
    final now = ref.watch(squadClockProvider).now();
    final offset = ref.watch(localOffsetProvider);
    final invite = state.invite;
    final expired = invite != null && invite.isExpired(now);
    return Scaffold(
      appBar: AppBar(title: Text(widget.demo ? 'Invite (demo)' : 'Invite')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.demo)
            const Material(
              color: Color(0xFFFFF3CD),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Demo. Not connected. This code stays on this phone.',
                  key: Key('invite-demo'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (state.loading)
            const Center(
              child: CircularProgressIndicator(key: Key('invite-loading')),
            )
          else if (state.notEnabled)
            const Text('Invites not enabled yet.', key: Key('invite-disabled'))
          else ...[
            Text(
              invite == null
                  ? 'No code yet. Make one when you want a friend to join.'
                  : invite.code,
              key: const Key('invite-code'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (invite != null) ...[
              const SizedBox(height: 8),
              Text(
                formatInviteExpiry(invite.expiresAt, offset),
                key: const Key('invite-expiry'),
              ),
              if (expired) const Text('Expired', key: Key('invite-expired')),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('invite-rotate'),
              onPressed: state.busy
                  ? null
                  : () {
                      unawaited(
                        ref.read(inviteControllerProvider.notifier).rotate(),
                      );
                    },
              child: Text(
                invite == null
                    ? 'Make a code'
                    : expired
                    ? 'Make a new code'
                    : 'New code',
              ),
            ),
            if (invite != null && !expired) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('invite-copy'),
                onPressed: () {
                  unawaited(ref.read(codeShareProvider).copy(invite.shareText));
                },
                child: const Text('Copy'),
              ),
              const SizedBox(height: 8),
              _ShareButton(text: invite.shareText),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(state.error!, key: const Key('invite-error')),
            ],
          ],
        ],
      ),
    );
  }
}

class _ShareButton extends ConsumerWidget {
  const _ShareButton({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      key: const Key('invite-share'),
      onPressed: () => unawaited(_share(context, ref)),
      child: const Text('Share'),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject();
    final Rect? raw = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await ref.read(codeShareProvider).share(text, origin: shareOrigin(raw));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sharing failed. Use Copy.', key: Key('share-failed')),
        ),
      );
    }
  }
}

class JoinCodeDialog extends ConsumerStatefulWidget {
  const JoinCodeDialog({super.key});

  @override
  ConsumerState<JoinCodeDialog> createState() => _JoinCodeDialogState();
}

class _JoinCodeDialogState extends ConsumerState<JoinCodeDialog> {
  final _code = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('join-dialog'),
      title: const Text('Join with a code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('join-code-field'),
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Code',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const Key('join-error')),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('join-submit'),
          onPressed: _busy ? null : () => unawaited(_submit()),
          child: const Text('Join'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final decision = await ref
        .read(inviteControllerProvider.notifier)
        .join(_code.text);
    if (!mounted) return;
    if (decision.joined) {
      Navigator.pop(context, true);
      return;
    }
    final error = decision.error ?? JoinError.invalid;
    setState(() {
      _busy = false;
      _error = joinErrorMessage(error);
    });
  }
}
