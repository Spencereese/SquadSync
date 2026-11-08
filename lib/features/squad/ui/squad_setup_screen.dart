import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/auth/ui/sign_out_button.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

/// Signed in, profile exists, no squad yet. Creates one squad of at most 8.
class SquadSetupScreen extends ConsumerStatefulWidget {
  const SquadSetupScreen({required this.profile, super.key});

  final Member profile;

  @override
  ConsumerState<SquadSetupScreen> createState() => _SquadSetupScreenState();
}

class _SquadSetupScreenState extends ConsumerState<SquadSetupScreen> {
  late final TextEditingController _name;
  late final TextEditingController _game;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.displayName);
    _game = TextEditingController(text: widget.profile.defaultGame);
  }

  @override
  void dispose() {
    _name.dispose();
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SquadSync'),
        actions: const [SignOutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Start the squad',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'One private squad, $squadCapacity people including you. '
            'You are the owner and cannot be removed. '
            'Call of Duty is the starting default game.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('setup-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('setup-game'),
            controller: _game,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Default game',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('start-squad'),
            onPressed: _busy ? null : _start,
            child: const Text('Create the squad'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('setup-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(squadRepositoryProvider)
          .saveProfile(displayName: _name.text, defaultGame: _game.text);
      await ref.read(squadRepositoryProvider).createMine();
      if (!mounted) return;
      ref.read(accountRevisionProvider.notifier).bump();
    } on RepositoryFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class ProfileMissingScreen extends ConsumerStatefulWidget {
  const ProfileMissingScreen({super.key});

  @override
  ConsumerState<ProfileMissingScreen> createState() =>
      _ProfileMissingScreenState();
}

class _ProfileMissingScreenState extends ConsumerState<ProfileMissingScreen> {
  final _name = TextEditingController();
  final _game = TextEditingController(text: 'Call of Duty');
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SquadSync'),
        actions: const [SignOutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Create your profile',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'This account has no SquadSync profile yet. This creates only your row. '
            'An existing name or default game is left as it is. '
            'If the server rejects it, nothing is saved.',
            key: Key('profile-missing'),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('profile-recover-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-recover-game'),
            controller: _game,
            decoration: const InputDecoration(
              labelText: 'Default game',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('profile-recover'),
            onPressed: _busy ? null : _recover,
            child: const Text('Create my profile'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('profile-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _recover() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(squadRepositoryProvider)
          .ensureMyProfile(displayName: _name.text, defaultGame: _game.text);
      if (!mounted) return;
      ref.read(accountRevisionProvider.notifier).bump();
    } on RepositoryFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Bumped after the squad is created so the gate loads the chat.
class AccountRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final accountRevisionProvider = NotifierProvider<AccountRevision, int>(
  AccountRevision.new,
);
