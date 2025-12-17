import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auto_merge_service.dart';
import '../../core/app_theme.dart';

/// Dialog showing merge suggestion with approve/dismiss actions
class MergeSuggestionDialog extends StatelessWidget {
  final Map<String, dynamic> notificationData;
  final VoidCallback onDismiss;

  const MergeSuggestionDialog({
    super.key,
    required this.notificationData,
    required this.onDismiss,
  });

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> notificationData,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MergeSuggestionDialog(
        notificationData: notificationData,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final friendName = notificationData['friend_name'] as String? ?? 'Unknown';
    final combinedSpots = notificationData['combined_spots'] as int? ?? 0;
    final mergeFromId = notificationData['merge_from_lobby_id'] as String?;
    final mergeToId = notificationData['merge_to_lobby_id'] as String?;
    final mergeId = notificationData['merge_id'] as String?;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: theme.glassyCard(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.merge_type,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Merge Lobbies?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              'You and $friendName started similar lobbies around the same time.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Would you like to merge them?',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),

            // Stats chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Combined: $combinedSpots spots',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (mergeId != null) {
                        AutoMergeService().dismissMergeSuggestion(mergeId);
                      }
                      onDismiss();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: theme.colorScheme.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Not Now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();

                      if (mergeFromId == null || mergeToId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid merge data'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        onDismiss();
                        return;
                      }

                      try {
                        // Show loading
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );

                        // Execute merge
                        await AutoMergeService().executeMerge(
                          mergeFromId,
                          mergeToId,
                        );

                        if (context.mounted) {
                          // Close loading
                          Navigator.of(context).pop();
                          // Close dialog
                          onDismiss();

                          // Show success
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Merged with $friendName\'s lobby!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          // Close loading if still showing
                          Navigator.of(context).pop();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to merge: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          onDismiss();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Merge',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
