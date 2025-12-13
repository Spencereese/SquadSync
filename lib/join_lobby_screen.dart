import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../services/auth_service_supabase.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;

class JoinLobbyScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const JoinLobbyScreen({super.key, this.initialCode});

  @override
  ConsumerState<JoinLobbyScreen> createState() => _JoinLobbyScreenState();
}

class _JoinLobbyScreenState extends ConsumerState<JoinLobbyScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join Lobby'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'DEBUG: 3 JOIN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(hintText: 'Invite Code'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _joinLobby,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Join'),
        ),
      ],
    );
  }

  Future<void> _joinLobby() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || !mounted) return;

    // Basic validation - lobby codes should be reasonable length
    if (code.length < 6 || code.length > 20) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid lobby code format')),
        );
      }
      return;
    }

    // Check for potentially malicious input
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(code)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Lobby code contains invalid characters')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = AuthServiceSupabase().currentUser;
      if (user == null) throw 'User not authenticated';

      await ref
          .read(ln.lobbyNotifierProvider.notifier)
          .joinLobby(code, user.id);
      HapticFeedback.lightImpact();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
