import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message_data.dart';

/// Message status indicator - shows sending status, delivery, read status, and timestamp
class MessageStatusIndicator extends StatelessWidget {
  final MessageStatus status;
  final DateTime timestamp;
  final bool showTimestamp;

  const MessageStatusIndicator({
    super.key,
    required this.status,
    required this.timestamp,
    this.showTimestamp = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTimestamp) ...[
            Text(
              _formatTime(timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
          ],
          _buildStatusIcon(theme),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(ThemeData theme) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.sending:
        return Semantics(
          label: 'Message is sending',
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      case MessageStatus.sent:
        icon = Icons.check;
        color = theme.colorScheme.onSurfaceVariant;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = theme.colorScheme.onSurfaceVariant;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = theme.colorScheme.primary;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = theme.colorScheme.error;
        break;
    }

    return Semantics(
      label: _getStatusLabel(),
      child: Icon(icon, size: 14, color: color),
    );
  }

  String _getStatusLabel() {
    switch (status) {
      case MessageStatus.sending:
        return 'Message is sending';
      case MessageStatus.sent:
        return 'Message sent';
      case MessageStatus.delivered:
        return 'Message delivered';
      case MessageStatus.read:
        return 'Message read';
      case MessageStatus.failed:
        return 'Message failed to send';
    }
  }

  String _formatTime(DateTime time) {
    // Convert to local time if needed
    final localTime = time.isUtc ? time.toLocal() : time;
    final now = DateTime.now();
    final difference = now.difference(localTime);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(localTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('M/d').format(localTime);
    }
  }
}
