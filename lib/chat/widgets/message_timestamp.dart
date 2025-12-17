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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Text(
              DateFormat('h:mm a').format(localTime),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
