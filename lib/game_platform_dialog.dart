import 'package:flutter/material.dart';

class GamePlatformConfig {
  final bool allowCrossplay;
  final List<String> selectedConsoles;

  const GamePlatformConfig({
    required this.allowCrossplay,
    required this.selectedConsoles,
  });

  bool get isValid => selectedConsoles.isNotEmpty;
}

class GamePlatformDialog extends StatefulWidget {
  final String gameName;

  const GamePlatformDialog({
    super.key,
    required this.gameName,
  });

  @override
  State<GamePlatformDialog> createState() => _GamePlatformDialogState();
}

class _GamePlatformDialogState extends State<GamePlatformDialog> {
  bool _allowCrossplay = true;
  final Set<String> _selectedConsoles = {};

  static const List<String> _availableConsoles = [
    'PlayStation',
    'Xbox',
    'PC',
    'Nintendo Switch',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.gameName} Platforms'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCrossplaySection(),
            const SizedBox(height: 16),
            _buildConsoleSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedConsoles.isNotEmpty
              ? () => Navigator.of(context).pop(GamePlatformConfig(
                    allowCrossplay: _allowCrossplay,
                    selectedConsoles: _selectedConsoles.toList(),
                  ))
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildCrossplaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Crossplay Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Allow Crossplay'),
          subtitle: const Text('Play with players on other platforms'),
          value: _allowCrossplay,
          onChanged: (value) {
            setState(() {
              _allowCrossplay = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildConsoleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Your Platforms',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose the platforms you use to play this game:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableConsoles.map((console) {
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
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getConsoleIcon(String console) {
    switch (console) {
      case 'PlayStation':
        return Icons.play_arrow; // Placeholder, you can use custom icons
      case 'Xbox':
        return Icons.games; // Placeholder
      case 'PC':
        return Icons.computer;
      case 'Nintendo Switch':
        return Icons.gamepad; // Placeholder
      default:
        return Icons.devices;
    }
  }
}
