import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../app_theme.dart';
import 'chat_service.dart';

class ChatModals {
  static void showChatOptions(BuildContext context, VoidCallback onClearChat,
      VoidCallback onChangeChatName, VoidCallback onChangeChatImage) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
              leading: Image.asset('assets/images/info_icon.png',
                  width: 24, height: 24),
              title: const Text('View Group Info'),
              onTap: () => Navigator.pop(context)),
          ListTile(
              leading: Image.asset('assets/images/notifications_off_icon.png',
                  width: 24, height: 24),
              title: const Text('Mute Notifications'),
              onTap: () => Navigator.pop(context)),
          ListTile(
              leading: Image.asset('assets/images/delete_sweep_icon.png',
                  width: 24, height: 24),
              title: const Text('Clear Chat',
                  style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(context);
                onClearChat();
              }),
          ListTile(
              leading: Image.asset('assets/images/exit_icon.png',
                  width: 24, height: 24),
              title: const Text('Leave Group',
                  style: TextStyle(color: AppTheme.errorColor)),
              onTap: () => Navigator.pop(context)),
          ListTile(
              leading: Image.asset('assets/images/search_icon.png',
                  width: 24, height: 24),
              title: const Text('Search Messages'),
              onTap: () {
                Navigator.pop(context);
                showSearchBar(context);
              }),
          ListTile(
              leading: Image.asset('assets/images/search_icon.png',
                  width: 24, height: 24),
              title: const Text('Change Chat Name'),
              onTap: () {
                Navigator.pop(context);
                onChangeChatName();
              }),
          ListTile(
              leading: Image.asset('assets/images/image_icon.png',
                  width: 24, height: 24),
              title: const Text('Change Chat Image'),
              onTap: () {
                Navigator.pop(context);
                onChangeChatImage();
              }),
          ListTile(
              leading: Image.asset('assets/images/bug_report_icon.png',
                  width: 24, height: 24),
              title: const Text('Report Bug'),
              onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  static void showSearchBar(BuildContext context) {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
                label: 'Search chat messages',
                child: TextField(
                    decoration: const InputDecoration(
                        hintText: 'Search messages...',
                        hintStyle: TextStyle(color: AppTheme.hintColor),
                        border: OutlineInputBorder()),
                    onChanged: (value) => searchQuery = value)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chat')
                    .orderBy('timestamp', descending: true)
                    .where('text', isGreaterThanOrEqualTo: searchQuery)
                    .where('text', isLessThan: '$searchQuery\uf8ff')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Center(
                        child: Text('Error loading search results'));
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var messages = snapshot.data!.docs;
                  if (messages.isEmpty)
                    return const Center(child: Text('No results found'));
                  return ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      var message = messages[index];
                      Map<String, dynamic> data =
                          message.data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['text'] ?? ''),
                        subtitle: Text(
                            "${message['sender']} - ${DateFormat('MMM d, yyyy, HH:mm').format((message['timestamp'] as Timestamp).toDate())}",
                            style: const TextStyle(color: AppTheme.hintColor)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showChangeChatNameDialog(
      BuildContext context, String currentName, Function(String) onSave) {
    final TextEditingController nameController =
        TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Change Chat Name'),
        content: Semantics(
            label: 'New chat name',
            child: TextField(
                controller: nameController,
                decoration: const InputDecoration(
                    hintText: 'Enter new chat name...',
                    hintStyle: TextStyle(color: AppTheme.hintColor)))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.hintColor))),
          TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  onSave(nameController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save',
                  style: TextStyle(color: AppTheme.accentColor))),
        ],
      ),
    );
  }

  static void showMessageDetails(
      BuildContext context, DocumentSnapshot message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Message Details'),
        content: Semantics(
            label:
                'Message sent at ${DateFormat('MMMM d, yyyy, HH:mm:ss').format((message['timestamp'] as Timestamp).toDate())}',
            child: Text(
                'Sent: ${DateFormat('MMM d, yyyy, HH:mm:ss').format((message['timestamp'] as Timestamp).toDate())}')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK',
                  style: TextStyle(color: AppTheme.accentColor)))
        ],
      ),
    );
  }

  static void showMessageOptions(
      BuildContext context,
      String docId,
      String currentText,
      bool isMe,
      ChatService chatService,
      VoidCallback onCopy,
      VoidCallback onForward) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        List<Widget> menuItems = [
          ListTile(
              leading: Image.asset('assets/images/copy_icon.png',
                  width: 24, height: 24),
              title: const Text('Copy'),
              onTap: () {
                onCopy();
                Navigator.pop(context);
              }),
          ListTile(
              leading: Image.asset('assets/images/forward_icon.png',
                  width: 24, height: 24),
              title: const Text('Forward'),
              onTap: () {
                onForward();
                Navigator.pop(context);
              }),
          ListTile(
              leading: Image.asset('assets/images/delete_icon.png',
                  width: 24, height: 24),
              title: const Text('Delete',
                  style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(context);
                showDeleteDialog(context, docId, chatService);
              }),
        ];
        if (isMe)
          menuItems.insert(
              0,
              ListTile(
                  leading: Image.asset('assets/images/edit_icon.png',
                      width: 24, height: 24),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    showEditDialog(context, docId, currentText, chatService);
                  }));
        return Column(mainAxisSize: MainAxisSize.min, children: menuItems);
      },
    );
  }

  static void showEditDialog(BuildContext context, String docId,
      String currentText, ChatService chatService) {
    TextEditingController editController =
        TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Edit Message'),
        content: Semantics(
            label: 'Edit message',
            child: TextField(
                controller: editController,
                decoration: const InputDecoration(
                    hintText: 'Edit your message...',
                    hintStyle: TextStyle(color: AppTheme.hintColor)))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.hintColor))),
          TextButton(
              onPressed: () {
                chatService.editMessage(docId, editController.text);
                Navigator.pop(context);
              },
              child: const Text('Save',
                  style: TextStyle(color: AppTheme.accentColor))),
        ],
      ),
    );
  }

  static void showDeleteDialog(
      BuildContext context, String docId, ChatService chatService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.hintColor))),
          TextButton(
              onPressed: () {
                chatService.deleteMessage(docId);
                Navigator.pop(context);
              },
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.errorColor))),
        ],
      ),
    );
  }

  static void showPlusMenu(BuildContext context, VoidCallback onSendMedia) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
              leading: const Icon(Icons.file_present),
              title: const Text('Share a file'),
              onTap: () => Navigator.pop(context)),
          ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Location'),
              onTap: () => Navigator.pop(context)),
          ListTile(
              leading: const Icon(Icons.poll),
              title: const Text('Poll'),
              onTap: () => Navigator.pop(context)),
          ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Photo/Video'),
              onTap: () {
                Navigator.pop(context);
                onSendMedia();
              }),
        ],
      ),
    );
  }
}
