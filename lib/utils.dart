import 'package:flutter/material.dart';

// Format timer with null safety and input validation
String formatTimer(int? seconds) {
  if (seconds == null || seconds < 0) return '00:00';

  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final secs = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$secs';
}

// Show a consistent snackbar across the app
void showSnackBar(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 3)}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
    ),
  );
}

// Show an error snackbar with red background
void showErrorSnackBar(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 4)}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: duration,
    ),
  );
}

// Show a success snackbar with green background
void showSuccessSnackBar(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 3)}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: duration,
    ),
  );
}

// Constants for badge thresholds
const _turkeyBadgeThreshold = 3;
const _duckBadgeThreshold = 4;
const _chickenBadgeThreshold = 10;

// Build badge widget with improved structure and configuration
Widget buildBadge(int streak, {double badgeSize = 16.0}) {
  if (streak < 0) return const SizedBox.shrink();

  final badges = <Widget>[];

  if (streak >= _chickenBadgeThreshold) {
    badges.add(_buildBadgeImage('chicken.png', badgeSize));
  } else if (streak >= _duckBadgeThreshold) {
    badges.add(_buildBadgeImage('duck.png', badgeSize));
  } else if (streak >= _turkeyBadgeThreshold) {
    badges.add(_buildBadgeImage('turkey.png', badgeSize));
  }

  return badges.isEmpty
      ? const SizedBox.shrink()
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: badges
              .map((badge) => Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: badge,
                  ))
              .toList(),
        );
}

// Helper method to create badge images
Widget _buildBadgeImage(String assetName, double size) {
  return Image.asset(
    'assets/images/$assetName',
    width: size,
    height: size,
    errorBuilder: (context, error, stackTrace) =>
        const Icon(Icons.error, size: 16),
  );
}

// Calculate average with error handling and precision
double calculateAverage(List<int> ratings) {
  if (ratings.isEmpty) return 0.0;

  try {
    final sum = ratings.reduce((a, b) => a + b);
    return double.parse((sum / ratings.length).toStringAsFixed(1));
  } catch (e) {
    return 0.0;
  }
}

// Safe display name helper
String safeDisplayName(String? name) => name ?? 'Unknown User';
