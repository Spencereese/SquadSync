import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'presentation/notifiers/squad_notifier.dart' as sn;

class JoinSquadScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const JoinSquadScreen({super.key, this.initialCode});

  @override
  ConsumerState<JoinSquadScreen> createState() => _JoinSquadScreenState();
}

class _JoinSquadScreenState extends ConsumerState<JoinSquadScreen> {
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
      title: const Text('Join Squad'),
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
          onPressed: _joinSquad,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Join'),
        ),
      ],
    );
  }

  Future<void> _joinSquad() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || !mounted) return;

    // Basic validation - squad codes should be reasonable length
    if (code.length < 6 || code.length > 20) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid squad code format')),
        );
      }
      return;
    }

    // Check for potentially malicious input
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(code)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Squad code contains invalid characters')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      await ref
          .read(sn.squadNotifierProvider.notifier)
          .joinSquad(code, user.uid);
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
