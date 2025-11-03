import 'package:flutter/material.dart';
import '../../squad_state.dart';
import 'base_dialog.dart';

/// Dialog for filing complaints against players
class ComplaintDialog extends StatefulWidget {
  final SquadState squadState;
  final String player;
  final ScaffoldMessengerState messenger;

  const ComplaintDialog({
    super.key,
    required this.squadState,
    required this.player,
    required this.messenger,
  });

  @override
  State<ComplaintDialog> createState() => _ComplaintDialogState();

  /// Static method to show the dialog (maintains compatibility)
  static void show(BuildContext context, ScaffoldMessengerState messenger,
      SquadState squadState, String player) {
    showDialog(
      context: context,
      builder: (dialogContext) => ComplaintDialog(
        squadState: squadState,
        player: player,
        messenger: messenger,
      ),
    );
  }
}

class _ComplaintDialogState extends State<ComplaintDialog> {
  String? reason;
  String? category;
  final categories = ['Behavior', 'Inactivity', 'Toxicity'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: BaseSquadDialog.dialogShape,
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
      actions: BaseSquadDialog.dialogActions(
        context: context,
        actions: [
          BaseSquadDialog.cancelButton(context),
          BaseSquadDialog.submitButton(
            context: context,
            text: 'Submit',
            onPressed: _submitComplaint,
            enabled: reason != null &&
                category != null &&
                widget.squadState.displayName != null,
          ),
        ],
      ),
    );
  }

  void _submitComplaint() async {
    if (reason != null &&
        category != null &&
        widget.squadState.displayName != null) {
      try {
        await widget.squadState.submitComplaint(
          targetMember: widget.player,
          reason: reason!,
          category: category!,
          submittedBy: widget.squadState.displayName!,
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
