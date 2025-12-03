import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/controllers/game_theme_controller.dart';
import '../../core/app_theme.dart';

/// Example widget demonstrating dynamic theme usage
///
/// Shows how to access theme colors and display theme info
class ThemePreviewCard extends ConsumerWidget {
  const ThemePreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeState = ref.watch(gameThemeControllerProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Game name
          if (themeState.currentGameName != null) ...[
            Text(
              themeState.currentGameName!,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Color swatches
          Row(
            children: [
              _ColorSwatch(
                label: 'Vibrant',
                color: themeState.vibrantColor,
              ),
              const SizedBox(width: 12),
              _ColorSwatch(
                label: 'Dominant',
                color: themeState.dominantColor,
              ),
              const SizedBox(width: 12),
              _ColorSwatch(
                label: 'Accent',
                color: themeState.accentColor,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Loading indicator
          if (themeState.isLoading)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Extracting colors...',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),

          // Error message
          if (themeState.error != null)
            Text(
              'Error: ${themeState.error}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red[300],
              ),
            ),

          const SizedBox(height: 16),

          // Example buttons with theme colors
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () {},
                child: const Text('Primary Action'),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Secondary'),
              ),
              TextButton(
                onPressed: () async {
                  await ref
                      .read(gameThemeControllerProvider.notifier)
                      .resetToDefault();
                },
                child: const Text('Reset Theme'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Color swatch display widget
class _ColorSwatch extends StatelessWidget {
  final String label;
  final Color color;

  const _ColorSwatch({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
          Text(
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Example screen showing theme integration
class ThemeTestScreen extends ConsumerWidget {
  const ThemeTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic Theme Demo'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemePreviewCard(),
            const SizedBox(height: 24),

            // Example of using NeonGlow extension from AppTheme
            Text(
              'Neon Glow Example',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                shadows: theme.colorScheme.primary.neonGlow(
                  blur: 20,
                  spread: 2,
                  opacity: 0.6,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Example glassmorphic card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
                boxShadow: theme.colorScheme.primary.neonGlow(
                  blur: 15,
                  spread: 1,
                  opacity: 0.3,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Glassmorphic Card',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This card automatically adapts to the game\'s theme colors.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
