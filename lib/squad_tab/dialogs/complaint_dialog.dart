import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../squad_state.dart';

/// Dialog for filing complaints against players
class ComplaintDialog extends ConsumerStatefulWidget {
  final String player;
  final ScaffoldMessengerState messenger;

  const ComplaintDialog({
    super.key,
    required this.player,
    required this.messenger,
  });

  @override
  ConsumerState<ComplaintDialog> createState() => _ComplaintDialogState();

  /// Static method to show the dialog (maintains compatibility)
  static void show(BuildContext context, ScaffoldMessengerState messenger,
      String player) {
    showDialog(
      context: context,
      builder: (dialogContext) => ComplaintDialog(
        player: player,
        messenger: messenger,
      ),
    );
  }
}

class _ComplaintDialogState extends ConsumerState<ComplaintDialog> {
  String? reason;
  String? category;
  final categories = ['Behavior', 'Inactivity', 'Toxicity'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('File Complaint Against ${widget.player}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Reason'),
            onChanged: (value) => reason = value,
          ),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Category'),
            items: categories
                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (value) => setState(() => category = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submitComplaint,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  void _submitComplaint() async {
    if (reason != null && category != null) {
      try {
        final currentUser = ref.read(squadStateNotifierProvider.notifier).authService.currentUser;
        if (currentUser == null) return;
        
        final squadMembers = ref.read(squadStateNotifierProvider).squadMemberUids;
        
        await ref.read(squadStateNotifierProvider.notifier).achievementManager.submitComplaint(
          submittedBy: currentUser.uid,
          targetMember: widget.player,
          reason: reason!,
          category: category!,
          squadMembers: squadMembers,
        );
        
        if (mounted) {
          Navigator.pop(context);
        }
        widget.messenger.showSnackBar(
          const SnackBar(content: Text('Complaint submitted')),
        );
      } catch (e) {
        widget.messenger.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
