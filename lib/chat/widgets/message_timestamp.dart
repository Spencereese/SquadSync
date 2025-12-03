import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Timestamp display component for messages
class MessageTimestamp extends StatelessWidget {
  final DateTime timestamp;

  const MessageTimestamp({
    super.key,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    // Convert to local time if needed
    final localTime = timestamp.isUtc ? timestamp.toLocal() : timestamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Semantics(
          label:
              'Message sent on ${DateFormat('MMMM d, yyyy, h:mm a').format(localTime)}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              DateFormat('h:mm a').format(localTime),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
