import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/message_data.dart';
import '../services/ai_service.dart';

class MediaHistoryScreen extends ConsumerStatefulWidget {
  final String? chatGroupId;
  final ChatType chatType;

  const MediaHistoryScreen({
    super.key,
    this.chatGroupId,
    required this.chatType,
  });

  @override
  ConsumerState<MediaHistoryScreen> createState() => _MediaHistoryScreenState();
}

class _MediaHistoryScreenState extends ConsumerState<MediaHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'all'; // all, images, videos, audio
  String _sortBy = 'newest'; // newest, oldest

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<MessageData>> _getMediaMessagesStream() {
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
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageData.fromDocument(doc))
          .where((message) {
            // Filter for media messages
            return message.photos.isNotEmpty ||
                message.videoUrl != null ||
                message.audioUrl != null;
          })
          .whereType<MessageData>()
          .toList();
    });
  }

  List<MessageData> _filterAndSortMedia(List<MessageData> messages) {
    // Filter by search query
    var filtered = messages.where((message) {
      if (_searchQuery.isEmpty) return true;
      final senderMatch =
          message.sender.toLowerCase().contains(_searchQuery.toLowerCase());
      final textMatch =
          message.text.toLowerCase().contains(_searchQuery.toLowerCase());
      return senderMatch || textMatch;
    }).toList();

    // Filter by media type
    filtered = filtered.where((message) {
      switch (_filterType) {
        case 'images':
          return message.photos.isNotEmpty;
        case 'videos':
          return message.videoUrl != null;
        case 'audio':
          return message.audioUrl != null;
        default:
          return true; // 'all'
      }
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
          // Filter and sort row
          Row(
            children: [
              // Media type filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterType,
                  decoration: const InputDecoration(
                    labelText: 'Media Type',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Media')),
                    DropdownMenuItem(value: 'images', child: Text('Images')),
                    DropdownMenuItem(value: 'videos', child: Text('Videos')),
                    DropdownMenuItem(value: 'audio', child: Text('Audio')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterType = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Sort order
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sortBy,
                  decoration: const InputDecoration(
                    labelText: 'Sort By',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'newest', child: Text('Newest First')),
                    DropdownMenuItem(
                        value: 'oldest', child: Text('Oldest First')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid(List<MessageData> mediaMessages) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: mediaMessages.length,
      itemBuilder: (context, index) {
        final message = mediaMessages[index];
        return _buildMediaItem(message);
      },
    );
  }

  Widget _buildMediaItem(MessageData message) {
    // Determine media type and URL
    IconData mediaIcon;
    Color mediaColor;

    if (message.photos.isNotEmpty) {
      mediaIcon = Icons.image;
      mediaColor = Colors.blue;
    } else if (message.videoUrl != null) {
      mediaIcon = Icons.video_library;
      mediaColor = Colors.red;
    } else if (message.audioUrl != null) {
      mediaIcon = Icons.audio_file;
      mediaColor = Colors.green;
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _showMediaDialog(message),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(mediaIcon, size: 32, color: mediaColor),
            const SizedBox(height: 4),
            Text(
              message.sender,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _formatTimestamp(message.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaDialog(MessageData message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Media from ${message.sender}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.photos.isNotEmpty) ...[
              const Text('Images:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...message.photos.map((photo) => Text('• ${photo['uri']}')),
            ],
            if (message.videoUrl != null) ...[
              const Text('Video:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• ${message.videoUrl}'),
            ],
            if (message.audioUrl != null) ...[
              const Text('Audio:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• ${message.audioUrl}'),
            ],
            const SizedBox(height: 8),
            Text('Message: ${message.text}'),
            Text('Time: ${_formatTimestamp(message.timestamp)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _filterType == 'images'
                ? Icons.image_not_supported
                : _filterType == 'videos'
                    ? Icons.video_library
                    : _filterType == 'audio'
                        ? Icons.audio_file
                        : Icons.perm_media,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No media found matching "$_searchQuery"'
                : 'No ${_filterType == 'all' ? 'media' : _filterType} found',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Media messages will appear here',
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media History'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: _buildFilters(),
        ),
      ),
      body: StreamBuilder<List<MessageData>>(
        stream: _getMediaMessagesStream(),
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
                  Text('Error loading media: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allMedia = snapshot.data ?? [];
          final filteredMedia = _filterAndSortMedia(allMedia);

          if (filteredMedia.isEmpty) {
            return _buildEmptyState();
          }

          return _buildMediaGrid(filteredMedia);
        },
      ),
    );
  }
}
