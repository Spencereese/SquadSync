import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import 'chat_state.dart';

class ChatSettingsMenu {
  static void showChatOptions({
    required BuildContext context,
    required VoidCallback onSearchMessages,
    required VoidCallback onChangeChatName,
    required VoidCallback onChangeChatImage,
    required VoidCallback onClearChat,
    required VoidCallback onQuickReactionPicker,
    required VoidCallback onToggleNotifications,
    required bool isMuted,
    required VoidCallback onViewGroupInfo,
    required VoidCallback onReportBug,
    required VoidCallback onLeaveGroup,
    required VoidCallback onViewMediaGallery,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              height: 4.0,
              width: 40.0,
              decoration: BoxDecoration(
                color: AppTheme.hintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
            _buildSectionTitle(context, 'Group Actions'),
            ListTile(
              leading: Image.asset('assets/images/info_icon.png',
                  width: 24, height: 24),
              title: const Text('View Group Info'),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.hintColor),
              onTap: () {
                Navigator.pop(context);
                onViewGroupInfo();
              },
            ),
            ListTile(
              leading: Image.asset(
                  isMuted
                      ? 'assets/images/notifications_off_icon.png'
                      : 'assets/images/notifications_icon.png',
                  width: 24,
                  height: 24),
              title:
                  Text(isMuted ? 'Unmute Notifications' : 'Mute Notifications'),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.hintColor),
              onTap: () {
                Navigator.pop(context);
                onToggleNotifications();
              },
            ),
            _buildSectionTitle(context, 'Chat Customization'),
            ListTile(
              leading: Image.asset('assets/images/edit_icon.png',
                  width: 24, height: 24),
              title: const Text('Change Chat Name'),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.hintColor),
              onTap: () {
                Navigator.pop(context);
                onChangeChatName();
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/image_icon.png',
                  width: 24, height: 24),
              title: const Text('Change Chat Image'),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.hintColor),
              onTap: () {
                Navigator.pop(context);
                onChangeChatImage();
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/emoji_icon.png',
                  width: 24, height: 24),
              title: const Text('Set Quick Reaction'),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.hintColor),
              onTap: () {
                Navigator.pop(context);
                onQuickReactionPicker();
              },
            ),
            _buildSectionTitle(context, 'Chat Management'),
            ListTile(
              leading: Image.asset('assets/images/photo_icon.png',
                  width: 24, height: 24),
              title: const Text('Media Gallery'),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.hintColor),
              onTap: () {
                Navigator.pop(context);
                onViewMediaGallery();
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/search_icon.png',
                  width: 24, height: 24),
              title: const Text('Search Messages'),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.hintColor),
              onTap: () {
                Navigator.pop(context);
                onSearchMessages();
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/delete_sweep_icon.png',
                  width: 24, height: 24),
              title: const Text('Clear Chat',
                  style: TextStyle(color: AppTheme.errorColor)),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.errorColor),
              onTap: () {
                Navigator.pop(context);
                onClearChat();
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/exit_icon.png',
                  width: 24, height: 24),
              title: const Text('Leave Group',
                  style: TextStyle(color: AppTheme.errorColor)),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.errorColor),
              onTap: () {
                Navigator.pop(context);
                onLeaveGroup();
              },
            ),
            _buildSectionTitle(context, 'Support'),
            ListTile(
              leading: Image.asset('assets/images/bug_report_icon.png',
                  width: 24, height: 24),
              title: const Text('Report Bug'),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.hintColor),
              onTap: () {
                Navigator.pop(context);
                onReportBug();
              },
            ),
            const SizedBox(height: 8.0),
          ],
        ),
      ),
    );
  }

  static Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.accentColor,
          fontWeight: FontWeight.bold,
          fontSize: 14.0,
        ),
      ),
    );
  }

  static void showQuickReactionPicker({
    required BuildContext context,
    required Function(List<String>) onEmojisSelected,
  }) {
    final chatState = Provider.of<ChatState>(context, listen: false);
    final currentEmojis = List<String>.from(chatState.quickReactionEmojis);
    final selectedEmojis = Set<String>.from(currentEmojis);

    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                height: 4.0,
                width: 40.0,
                decoration: BoxDecoration(
                  color: AppTheme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Select Quick Reactions (${selectedEmojis.length}/6)',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Choose up to 6 emojis for your quick reactions',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    fontSize: 14.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  '👍',
                  '❤️',
                  '😂',
                  '😮',
                  '😢',
                  '😡',
                  '😍',
                  '🤔',
                  '🙄',
                  '😴',
                  '🤗',
                  '🤩',
                  '🥳',
                  '😎',
                  '🤯',
                  '😱',
                  '🤪',
                  '🥺',
                  '😤',
                  '🤐',
                  '👏',
                  '🙌',
                  '🤝',
                  '👌',
                  '✌️',
                  '🤞',
                  '💪',
                  '🙏',
                  '🤙',
                  '👋',
                  '🔥',
                  '⭐',
                  '✨',
                  '💯',
                  '🎉',
                  '🎊',
                  '💖',
                  '💕',
                  '💓',
                  '💗',
                  '💜',
                  '💙',
                  '💚',
                  '💛',
                  '🧡',
                  '❤️‍🔥',
                  '💔',
                  '❣️',
                  '💞',
                  '💘'
                ].map((emoji) {
                  final isSelected = selectedEmojis.contains(emoji);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedEmojis.remove(emoji);
                        } else if (selectedEmojis.length < 6) {
                          selectedEmojis.add(emoji);
                        }
                      });
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.2)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.3),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                        semanticsLabel: isSelected
                            ? 'Remove $emoji from quick reactions'
                            : 'Add $emoji to quick reactions',
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedEmojis.isNotEmpty
                            ? () {
                                final sortedEmojis = selectedEmojis.toList()
                                  ..sort();
                                onEmojisSelected(sortedEmojis);
                                Navigator.pop(context);
                              }
                            : null,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8.0),
            ],
          ),
        ),
      ),
    );
  }

  static void showSearchBar({
    required BuildContext context,
    required FirebaseFirestore firestore,
    required String searchQuery,
    required Function(String) onSearchQueryChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  height: 4.0,
                  width: 40.0,
                  decoration: BoxDecoration(
                    color: AppTheme.hintColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
                Semantics(
                  label: 'Search chat messages',
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search messages...',
                      hintStyle: TextStyle(color: AppTheme.hintColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      prefixIcon: Icon(Icons.search, color: AppTheme.hintColor),
                    ),
                    onChanged: onSearchQueryChanged,
                  ),
                ),
                const SizedBox(height: 16.0),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: () {
                      // Check if user is authenticated
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) {
                        return Stream<QuerySnapshot>.empty();
                      }
                      return firestore
                          .collection('chat')
                          .orderBy('timestamp', descending: true)
                          .where('text', isGreaterThanOrEqualTo: searchQuery)
                          .where('text', isLessThan: '$searchQuery\uf8ff')
                          .snapshots();
                    }(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Error loading search results',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      var messages = snapshot.data!.docs;
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            'No results found',
                            style: TextStyle(color: AppTheme.hintColor),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          var message = messages[index];
                          Map<String, dynamic> data =
                              message.data() as Map<String, dynamic>;
                          return Card(
                            color: Theme.of(context).colorScheme.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              title: Text(
                                (data['text'] ?? '')
                                    .replaceAll('â', "'")
                                    .replaceAll('€', "")
                                    .replaceAll('™', "'"),
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                              ),
                              subtitle: Text(
                                "${message['sender']} • ${DateFormat('MMM d, yyyy, HH:mm').format((message['timestamp'] as Timestamp).toDate())}",
                                style: TextStyle(color: AppTheme.hintColor),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showChangeChatNameDialog({
    required BuildContext context,
    required String currentName,
    required Function(String) onSave,
  }) {
    final TextEditingController nameController =
        TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: const Text('Change Chat Name'),
        content: Semantics(
          label: 'New chat name',
          child: TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: 'Enter new chat name...',
              hintStyle: TextStyle(color: AppTheme.hintColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.hintColor)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                onSave(nameController.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static void showMessageOptions({
    required BuildContext context,
    required String docId,
    required String currentText,
    required bool isMe,
    required VoidCallback onCopy,
    required Function(String) onEdit,
    required VoidCallback onDelete,
    required Function(String) onReact,
    required VoidCallback onForward,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        List<Widget> menuItems = [];

        if (isMe) {
          menuItems.add(
            ListTile(
              leading: Image.asset('assets/images/edit_icon.png',
                  width: 24, height: 24),
              title: const Text('Edit'),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.hintColor),
              onTap: () {
                Navigator.pop(context);
                TextEditingController editController =
                    TextEditingController(text: currentText);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0)),
                    title: const Text('Edit Message'),
                    content: Semantics(
                      label: 'Edit message',
                      child: TextField(
                        controller: editController,
                        decoration: InputDecoration(
                          hintText: 'Edit your message...',
                          hintStyle: TextStyle(color: AppTheme.hintColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppTheme.hintColor)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          onEdit(editController.text);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                height: 4.0,
                width: 40.0,
                decoration: BoxDecoration(
                  color: AppTheme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              ...menuItems,
            ],
          ),
        );
      },
    );
  }
}
