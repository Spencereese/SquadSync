import 'package:flutter/material.dart';
import '../widgets/dialog_variants.dart';
import '../chat/dialogs/invite_members_dialog_new.dart';
import '../chat/dialogs/find_groups_dialog_new.dart';
import '../chat/dialogs/add_friend_dialog_new.dart';

/// Example usage of the specialized dialog variants
class DialogExamplesScreen extends StatelessWidget {
  const DialogExamplesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialog Examples'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExampleButton(
            context,
            'Confirmation Dialog',
            () => _showConfirmationDialog(context),
          ),
          _buildExampleButton(
            context,
            'Input Dialog',
            () => _showInputDialog(context),
          ),
          _buildExampleButton(
            context,
            'Selection Dialog',
            () => _showSelectionDialog(context),
          ),
          _buildExampleButton(
            context,
            'Success Feedback',
            () => _showSuccessFeedback(context),
          ),
          _buildExampleButton(
            context,
            'Error Feedback',
            () => _showErrorFeedback(context),
          ),
          _buildExampleButton(
            context,
            'Invite Members Dialog',
            () => _showInviteMembersDialog(context),
          ),
          _buildExampleButton(
            context,
            'Find Groups Dialog',
            () => _showFindGroupsDialog(context),
          ),
          _buildExampleButton(
            context,
            'Add Friend Dialog',
            () => _showAddFriendDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleButton(
      BuildContext context, String title, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(title),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        message:
            'Are you sure you want to delete this item? This action cannot be undone.',
        confirmText: 'Delete',
        cancelText: 'Cancel',
        isDestructive: true,
        onConfirm: () {
          // Handle delete action
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted')),
          );
        },
      ),
    );
  }

  void _showInputDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => InputDialog(
        label: 'Squad Name',
        hint: 'Enter a name for your squad',
        initialValue: 'My Squad',
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Squad name is required';
          }
          if (value.length < 3) {
            return 'Squad name must be at least 3 characters';
          }
          return null;
        },
        onConfirm: (value) {
          // Handle squad creation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Squad "$value" created')),
          );
        },
      ),
    );
  }

  void _showSelectionDialog(BuildContext context) {
    final options = [
      SelectionOption(
        value: 'warzone',
        label: 'Warzone',
        description: 'Battle Royale with up to 150 players',
        icon: Icons.public,
      ),
      SelectionOption(
        value: 'mw3',
        label: 'Modern Warfare III',
        description: 'Multiplayer FPS with various game modes',
        icon: Icons.sports_esports,
      ),
      SelectionOption(
        value: 'fortnite',
        label: 'Fortnite',
        description: 'Battle Royale with building mechanics',
        icon: Icons.home_work,
      ),
    ];

    showDialog(
      context: context,
      builder: (context) => SelectionDialog<String>(
        title: 'Choose Your Game',
        options: options,
        selectedValue: 'warzone',
        onSelected: (value) {
          // Handle game selection
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selected game: $value')),
          );
        },
      ),
    );
  }

  void _showSuccessFeedback(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const FeedbackDialog(
        message: 'Squad created successfully!',
        isSuccess: true,
        actionText: 'Invite Members',
        autoDismissDelay: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorFeedback(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const FeedbackDialog(
        message: 'Failed to join squad. Please check the code and try again.',
        isSuccess: false,
        actionText: 'Try Again',
        autoDismissDelay: Duration(seconds: 4),
      ),
    );
  }

  void _showInviteMembersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const InviteMembersDialog(
        chatGroupId: 'example_group_id',
        chatGroupName: 'Example Squad',
        isSquadGroup: true,
      ),
    );
  }

  void _showFindGroupsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const FindGroupsDialog(),
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddFriendDialog(),
    );
  }
}
