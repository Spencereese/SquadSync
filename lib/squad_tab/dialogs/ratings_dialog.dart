import 'package:flutter/material.dart';
import '../../domain/entities/lobby_state.dart';

/// Dialog for rating players with star ratings
class RatingsDialog extends StatefulWidget {
  final LobbyState squadState;
  final String player;
  final ScaffoldMessengerState messenger;

  const RatingsDialog({
    super.key,
    required this.squadState,
    required this.player,
    required this.messenger,
  });

  @override
  State<RatingsDialog> createState() => _RatingsDialogState();

  /// Static method to show the dialog (maintains compatibility)
  static void show(BuildContext context, ScaffoldMessengerState messenger,
      LobbyState squadState, String player) {
    final canRate = squadState.canRateMember(player);

    if (!canRate) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('You can only rate members you played with')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => RatingsDialog(
        squadState: squadState,
        player: player,
        messenger: messenger,
      ),
    );
  }
}

class _RatingsDialogState extends State<RatingsDialog> {
  final ratings = <String, int?>{
    'Vibes': null,
    'Comms': null,
    'Gunny': null,
    'Wingman': null
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text('Rate ${widget.player}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: ratings.keys
            .map((category) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(category),
                    Row(
                      children: List.generate(
                          5,
                          (index) => IconButton(
                                icon: Icon(
                                  index < (ratings[category] ?? 0)
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.yellowAccent,
                                ),
                                onPressed: () => setState(
                                    () => ratings[category] = index + 1),
                              )),
                    ),
                  ],
                ))
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitRatings,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  void _submitRatings() async {
    try {
      final filteredRatings =
          ratings.map((key, value) => MapEntry(key, value ?? 0));
      await widget.squadState.submitRatings(widget.player, filteredRatings);
      if (mounted) {
        Navigator.pop(context);
      }
      widget.messenger.showSnackBar(
        const SnackBar(content: Text('Ratings submitted')),
      );
    } catch (e) {
      widget.messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
