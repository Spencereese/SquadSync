import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/base_dialog.dart';
import '../../managers/user_manager.dart';
import '../../services/ai_service.dart';
import '../chat_screen.dart';

/// Dialog for adding friends and starting direct messages using BaseDialog
class AddFriendDialog extends BaseDialog {
  const AddFriendDialog({super.key});

  @override
  BaseDialogState<BaseDialog> createState() => _AddFriendDialogState();

  @override
  String? get title => 'Add Friend';

  @override
  bool get showCloseButton => true;

  @override
  bool get dismissible => true;

  @override
  double? get maxWidth => 600;

  @override
  List<Widget>? buildActions(BuildContext context) => null;

  @override
  Widget buildContent(BuildContext context) {
    final state = context.findAncestorStateOfType<_AddFriendDialogState>();
    if (state == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Search Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: state._searchController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              filled: true,
              fillColor:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.send,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () =>
                    state._searchUsers(state._searchController.text.trim()),
              ),
            ),
            onSubmitted: state._searchUsers,
          ),
        ),

        const SizedBox(height: 16),

        // Results
        Expanded(
          child: state._searchResults.isEmpty &&
                  state._searchController.text.isNotEmpty
              ? Center(
                  child: Text(
                    'No users found',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: state._searchResults.length,
                  itemBuilder: (context, index) {
                    final user = state._searchResults[index];
                    return state._buildUserListTile(user);
                  },
                ),
        ),
      ],
    );
  }
}

class _AddFriendDialogState extends BaseDialogState<AddFriendDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length >= 2) {
      final userManager = Provider.of<UserManager>(context, listen: false);
      final results = await userManager.searchUsers(query);
      setState(() => _searchResults = results);
    } else {
      setState(() => _searchResults = []);
    }
  }

  Future<void> _startDM(Map<String, dynamic> user) async {
    Navigator.pop(context); // Close search
    final userManager = Provider.of<UserManager>(context, listen: false);
    final chatId = await userManager.startDMThread(user['uid']);
    if (chatId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatGroupId: chatId,
            chatGroupName: user['displayName'] ?? 'Unknown',
            chatType: ChatType.dm,
          ),
        ),
      );
    }
  }

  Widget _buildUserListTile(Map<String, dynamic> user) {
    final displayName = user['displayName'] ?? 'Unknown';
    final profileImage = user['profileImage'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundImage:
              profileImage != null ? NetworkImage(profileImage) : null,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.2),
          child: profileImage == null
              ? Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          displayName,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '@${user['uid']}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => _startDM(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Start DM'),
        ),
      ),
    );
  }
}
