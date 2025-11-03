import 'package:flutter/material.dart';
import '../../squad_state.dart';
import 'base_dialog.dart';

/// Dialog for rating players with star ratings
class RatingsDialog extends StatefulWidget {
  final SquadState squadState;
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
      SquadState squadState, String player) async {
    final canRate = squadState.displayName != null
        ? await squadState.canRateMember(player, squadState.displayName!)
        : false;

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
      shape: BaseSquadDialog.dialogShape,
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
      actions: BaseSquadDialog.dialogActions(
        context: context,
        actions: [
          BaseSquadDialog.cancelButton(context),
          BaseSquadDialog.submitButton(
            context: context,
            text: 'Submit',
            onPressed: _submitRatings,
            enabled: widget.squadState.displayName != null,
          ),
        ],
      ),
    );
  }

  void _submitRatings() async {
    if (widget.squadState.displayName != null) {
      try {
        await widget.squadState.submitRatings(
          targetMember: widget.player,
          ratings: ratings,
          submittedBy: widget.squadState.displayName!,
        );
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
}
