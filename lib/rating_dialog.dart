import 'package:flutter/material.dart';

class RatingDialog {
  static void showRatingDialog(
    BuildContext context,
    List<String> walkingPlayers,
    Function(Map<String, Map<String, int>>) onSubmit,
  ) {
    Map<String, Map<String, double>> ratings = {
      for (var player in walkingPlayers)
        player: {'Vibes': 1.0, 'Comms': 1.0, 'Gunny': 1.0, 'Wingman': 1.0},
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[850],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Rate Your Squad',
                  style: TextStyle(
                      color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: walkingPlayers.map((player) {
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
                              _buildSlider(
                                  'Vibes',
                                  ratings[player]!['Vibes']!,
                                  (value) => setDialogState(
                                      () => ratings[player]!['Vibes'] = value)),
                              _buildSlider(
                                  'Comms',
                                  ratings[player]!['Comms']!,
                                  (value) => setDialogState(
                                      () => ratings[player]!['Comms'] = value)),
                              _buildSlider(
                                  'Gunny',
                                  ratings[player]!['Gunny']!,
                                  (value) => setDialogState(
                                      () => ratings[player]!['Gunny'] = value)),
                              _buildSlider(
                                  'Wingman',
                                  ratings[player]!['Wingman']!,
                                  (value) => setDialogState(() =>
                                      ratings[player]!['Wingman'] = value)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final intRatings = ratings.map(
                      (key, value) => MapEntry(
                          key, value.map((k, v) => MapEntry(k, v.toInt()))),
                    );
                    onSubmit(intRatings);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildSlider(
      String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            Text(value.toInt().toString(),
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        Slider(
          value: value,
          min: 1.0,
          max: 10.0,
          divisions: 9,
          label: value.toInt().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
