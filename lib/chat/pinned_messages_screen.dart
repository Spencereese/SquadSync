import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/message_data.dart';
import '../services/ai_service.dart';
import 'chat_service.dart';
import 'message_bubble.dart';

class PinnedMessagesScreen extends StatefulWidget {
  final String? chatGroupId;
  final ChatType chatType;

  const PinnedMessagesScreen({
    super.key,
    this.chatGroupId,
    required this.chatType,
  });

  @override
  State<PinnedMessagesScreen> createState() => _PinnedMessagesScreenState();
}

class _PinnedMessagesScreenState extends State<PinnedMessagesScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'newest'; // newest, oldest

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<MessageData>> _getPinnedMessagesStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    String collectionPath;
    if (widget.chatType == ChatType.userGroup) {
      collectionPath =
          'users/${currentUser.uid}/chat_groups/${widget.chatGroupId}/messages';
    } else if (widget.chatType == ChatType.dm) {
      collectionPath = 'chats/${widget.chatGroupId}/messages';
    } else {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection(collectionPath)
        .where('pinned', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageData.fromDocument(doc))
          .whereType<MessageData>()
          .toList();
    });
  }

  List<MessageData> _filterAndSortMessages(List<MessageData> messages) {
    // Filter by search query
    var filtered = messages.where((message) {
      if (_searchQuery.isEmpty) return true;
      final senderMatch =
          message.sender.toLowerCase().contains(_searchQuery.toLowerCase());
      final textMatch =
          message.text.toLowerCase().contains(_searchQuery.toLowerCase());
      return senderMatch || textMatch;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'oldest':
          return a.timestamp.compareTo(b.timestamp);
        default: // 'newest'
          return b.timestamp.compareTo(a.timestamp);
      }
    });

    return filtered;
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by sender or message...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          // Sort order
          DropdownButtonFormField<String>(
            initialValue: _sortBy,
            decoration: const InputDecoration(
              labelText: 'Sort By',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'newest', child: Text('Newest First')),
              DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
            ],
            onChanged: (value) {
              setState(() {
                _sortBy = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<MessageData> messages) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pin indicator
              Row(
                children: [
                  const Icon(Icons.push_pin, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Pinned',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Unpin button
                  IconButton(
                    icon: const Icon(Icons.push_pin_outlined, size: 20),
                    onPressed: () => _unpinMessage(message.id),
                    tooltip: 'Unpin message',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Message bubble
              MessageBubble(
                message: message,
                isMe:
                    message.senderUid == FirebaseAuth.instance.currentUser?.uid,
                showSender: true,
                showAvatar: true,
                showTimestamp: true,
                showReadIndicator: false,
                onTap: () {},
                onLongPress: () {},
                sendingStatus: const {},
                chatGroupId: widget.chatGroupId,
                chatType: widget.chatType,
                chatService: _chatService,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _unpinMessage(String messageId) async {
    try {
      await _chatService.unpinMessage(
          messageId, widget.chatGroupId, widget.chatType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message unpinned')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unpin message: $e')),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.push_pin_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No pinned messages found matching "$_searchQuery"'
                : 'No pinned messages',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pin important messages to keep them easily accessible',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pinned Messages'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: _buildFilters(),
        ),
      ),
      body: StreamBuilder<List<MessageData>>(
        stream: _getPinnedMessagesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading pinned messages: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allMessages = snapshot.data ?? [];
          final filteredMessages = _filterAndSortMessages(allMessages);

          if (filteredMessages.isEmpty) {
            return _buildEmptyState();
          }

          return _buildMessageList(filteredMessages);
        },
      ),
    );
  }
}
