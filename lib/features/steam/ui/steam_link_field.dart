import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';

/// The signed-in person's own Steam link. Other people's ids are not shown.
class SteamLinkField extends ConsumerStatefulWidget {
  const SteamLinkField({super.key});

  @override
  ConsumerState<SteamLinkField> createState() => _SteamLinkFieldState();
}

class _SteamLinkFieldState extends ConsumerState<SteamLinkField> {
  final _steam = TextEditingController();
  String? _message;
  String? _linked;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _steam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('steam-link'),
          controller: _steam,
          decoration: const InputDecoration(
            labelText: 'SteamID64 or vanity URL',
          ),
        ),
        const SizedBox(height: 8),
        Text(_status(), key: const Key('steam-link-status')),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('steam-link-save'),
            onPressed: () => unawaited(_save()),
            child: const Text('Link Steam'),
          ),
        ),
      ],
    );
  }

  String _status() {
    if (_message != null) return _message!;
    if (_linked != null) return 'Linked $_linked';
    return 'Steam not linked';
  }

  Future<void> _load() async {
    final link = await ref.read(steamRepositoryProvider).mine();
    if (!mounted) return;
    setState(() {
      _linked = link?.steamId;
      if (link != null) _steam.text = link.steamId;
    });
  }

  Future<void> _save() async {
    final result = await ref.read(steamRepositoryProvider).link(_steam.text);
    if (!mounted) return;
    setState(() {
      _linked = result.link?.steamId;
      _message = result.saved ? null : result.message;
    });
  }
}
