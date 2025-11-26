import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/squad_notifier.dart';

class RiverpodRatingDialog {
  static void showRatingDialog(
    BuildContext context,
    List<String> walkingPlayers,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _RatingDialogContent(walkingPlayers: walkingPlayers);
      },
    );
  }
}

class _RatingDialogContent extends ConsumerStatefulWidget {
  final List<String> walkingPlayers;

  const _RatingDialogContent({required this.walkingPlayers});

  @override
  ConsumerState<_RatingDialogContent> createState() =>
      _RatingDialogContentState();
}

class _RatingDialogContentState extends ConsumerState<_RatingDialogContent> {
  late Map<String, Map<String, double>> _tempRatings;

  @override
  void initState() {
    super.initState();
    // Initialize temp ratings from current state
    final squadState = ref.read(squadNotifierProvider).value;
    _tempRatings = {};
    for (var player in widget.walkingPlayers) {
      _tempRatings[player] = {
        'Vibes': (squadState?.dailyRatings[player]?['Vibes'] ?? 5).toDouble(),
        'Comms': (squadState?.dailyRatings[player]?['Comms'] ?? 5).toDouble(),
        'Gunny': (squadState?.dailyRatings[player]?['Gunny'] ?? 5).toDouble(),
        'Wingman':
            (squadState?.dailyRatings[player]?['Wingman'] ?? 5).toDouble(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Rate Your Squad',
          style: TextStyle(
              color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'RIVERPOD VERSION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              ...widget.walkingPlayers.map((player) {
                return Card(
                  color: Colors.grey[900],
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(player,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildSlider('Vibes', player, 'Vibes'),
                        _buildSlider('Comms', player, 'Comms'),
                        _buildSlider('Gunny', player, 'Gunny'),
                        _buildSlider('Wingman', player, 'Wingman'),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          onPressed: () async {
            // Submit ratings using Riverpod
            final ratingsToSubmit = <String, Map<String, int>>{};
            _tempRatings.forEach((player, ratings) {
              ratingsToSubmit[player] =
                  ratings.map((key, value) => MapEntry(key, value.toInt()));
            });

            for (var entry in ratingsToSubmit.entries) {
              await ref
                  .read(squadNotifierProvider.notifier)
                  .submitRatings(entry.key, entry.value);
            }

            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
          child: const Text('Submit'),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, String player, String category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            Text(_tempRatings[player]![category]!.toInt().toString(),
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        Slider(
          value: _tempRatings[player]![category]!,
          min: 1.0,
          max: 10.0,
          divisions: 9,
          label: _tempRatings[player]![category]!.toInt().toString(),
          onChanged: (value) {
            setState(() {
              _tempRatings[player]![category] = value;
            });
          },
        ),
      ],
    );
  }
}
