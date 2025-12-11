import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

/// Message search delegate for searching through chat messages
/// Uses Supabase for full-text search:
/// supabase.from('chat_messages').select().textSearch('content', query)
class ChatMessageSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Text(
          'Search messages...',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    // Supabase implementation with ilike for case-insensitive search
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.client
          .from('chat_messages')
          .select()
          .ilike('text', '%$query%')
          .limit(50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Text(
              'No messages found',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final data = messages[index];
            final text = data['text'] as String? ?? '';
            final senderName = data['sender_name'] as String? ?? 'Unknown';
            final timestampStr = data['timestamp'] as String?;

            return ListTile(
              title: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                senderName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              trailing: timestampStr != null
                  ? Text(
                      _formatTimestamp(timestampStr),
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : null,
              onTap: () {
                close(context, data['id'] as String? ?? '');
              },
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(String timestampStr) {
    final date = DateTime.parse(timestampStr);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
