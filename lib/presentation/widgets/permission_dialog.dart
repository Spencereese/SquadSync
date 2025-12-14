import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable dialog widget that explains why a permission is needed
/// Shows BEFORE the system permission prompt to improve user understanding
class PermissionRationaleDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onAllow;
  final VoidCallback? onCancel;

  const PermissionRationaleDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.onAllow,
    this.onCancel,
  });

  /// Factory for microphone permission dialog
  factory PermissionRationaleDialog.microphone({
    required VoidCallback onAllow,
    VoidCallback? onCancel,
  }) {
    return PermissionRationaleDialog(
      title: 'Microphone Access Required',
      message:
          'SquadSync needs access to your microphone to enable voice chat with your squad. '
          'Your privacy is important - we only access the microphone during active voice sessions.',
      icon: Icons.mic_rounded,
      onAllow: onAllow,
      onCancel: onCancel,
    );
  }

  /// Factory for camera permission dialog
  factory PermissionRationaleDialog.camera({
    required VoidCallback onAllow,
    VoidCallback? onCancel,
  }) {
    return PermissionRationaleDialog(
      title: 'Camera Access Required',
      message:
          'SquadSync needs access to your camera to enable video chat with your squad. '
          'Your privacy is important - we only access the camera during active video sessions.',
      icon: Icons.videocam_rounded,
      onAllow: onAllow,
      onCancel: onCancel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.2),
              blurRadius: 24,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with glow effect
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 36,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Message
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                // Cancel button
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        onCancel ?? () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurface.withOpacity(0.7),
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Allow button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onAllow();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      shadowColor: colorScheme.primary.withOpacity(0.4),
                    ),
                    child: Text(
                      'Allow',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
