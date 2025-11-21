import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_service.dart';
import '../../utils.dart';
import '../../providers.dart';
import '../chat_screen.dart';

/// Dialog for adding friends and starting direct messages
class AddFriendDialog extends ConsumerStatefulWidget {
  const AddFriendDialog({super.key});

  @override
  ConsumerState<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends ConsumerState<AddFriendDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length >= 2) {
      final userManager = ref.read(userManagerProvider);
      final results = await userManager.searchUsers(query);
      if (mounted) setState(() => _searchResults = results);
    } else {
      if (mounted) setState(() => _searchResults = []);
    }
  }

  Future<void> _startDM(Map<String, dynamic> user) async {
    Navigator.pop(context); // Close search
    final userManager = ref.read(userManagerProvider);
    final chatId = await userManager.startDMThread(user['uid']);
    if (chatId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatGroupId: chatId,
            chatGroupName: safeDisplayName(user['displayName'] as String?),
            chatType: ChatType.dm,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Add Friend',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.cyanAccent),
                    onPressed: () =>
                        _searchUsers(_searchController.text.trim()),
                  ),
                ),
                onSubmitted: _searchUsers,
              ),
            ),
            // Results
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  final displayName = safeDisplayName(user['displayName'] as String?);
                  final profileImage = user['profileImage'];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profileImage != null
                          ? NetworkImage(profileImage)
                          : null,
                      child: profileImage == null
                          ? Text(displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?')
                          : null,
                    ),
                    title: Text(displayName,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text('@${user['uid']}',
                        style: TextStyle(color: Colors.grey[400])),
                    trailing: ElevatedButton(
                      onPressed: () => _startDM(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Start DM'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
