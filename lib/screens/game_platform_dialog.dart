import 'package:flutter/material.dart';

/// Configuration for a game's platform settings
class GamePlatformConfig {
  final bool allowCrossplay;
  final Set<String> selectedConsoles;

  const GamePlatformConfig({
    required this.allowCrossplay,
    required this.selectedConsoles,
  });

  bool get hasSelectedConsoles => selectedConsoles.isNotEmpty;
}

/// Dialog for configuring game platform settings
class GamePlatformDialog extends StatefulWidget {
  final Map<String, dynamic> game;

  const GamePlatformDialog({
    super.key,
    required this.game,
  });

  @override
  State<GamePlatformDialog> createState() => _GamePlatformDialogState();
}

class _GamePlatformDialogState extends State<GamePlatformDialog> {
  bool _allowCrossplay = true; // Default to allowing crossplay
  final Set<String> _selectedConsoles = {};

  // Available console platforms
  static const List<String> _availableConsoles = [
    'PC',
    'PlayStation',
    'Xbox',
    'Nintendo Switch',
    'Mobile',
  ];

  @override
  Widget build(BuildContext context) {
    final gamePlatforms = widget.game['platforms'] as List<dynamic>? ?? [];
    final availableConsoles = _availableConsoles
        .where((console) => gamePlatforms.contains(console))
        .toList();

    return AlertDialog(
      title: Column(
        children: [
          Text(
            'Configure ${widget.game['name']}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Select your platforms and preferences',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Crossplay toggle
            _buildCrossplaySection(),

            const SizedBox(height: 24),

            // Console selection
            _buildConsoleSection(availableConsoles),

            const SizedBox(height: 16),

            // Info text
            Text(
              'Select at least one platform to continue',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedConsoles.isNotEmpty ? _onContinue : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildCrossplaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crossplay',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Allow Crossplay',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Play with players on other platforms',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _allowCrossplay,
                onChanged: (value) {
                  setState(() {
                    _allowCrossplay = value;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConsoleSection(List<String> availableConsoles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Platforms',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        if (availableConsoles.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No platforms available for this game',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableConsoles.map((console) {
              final isSelected = _selectedConsoles.contains(console);
              return FilterChip(
                label: Text(console),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedConsoles.add(console);
                    } else {
                      _selectedConsoles.remove(console);
                    }
                  });
                },
                avatar: Icon(
                  _getConsoleIcon(console),
                  size: 18,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  IconData _getConsoleIcon(String console) {
    switch (console.toLowerCase()) {
      case 'pc':
        return Icons.computer;
      case 'playstation':
        return Icons.sports_esports;
      case 'xbox':
        return Icons.gamepad;
      case 'nintendo switch':
        return Icons.videogame_asset;
      case 'mobile':
        return Icons.smartphone;
      default:
        return Icons.devices;
    }
  }

  void _onContinue() {
    if (_selectedConsoles.isEmpty) return;

    final config = GamePlatformConfig(
      allowCrossplay: _allowCrossplay,
      selectedConsoles: _selectedConsoles,
    );

    Navigator.of(context).pop(config);
  }
}
