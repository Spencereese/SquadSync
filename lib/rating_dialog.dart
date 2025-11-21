import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'squad_state.dart'; // Assuming this is where SquadState is defined

class RatingDialog {
  static void showRatingDialog(
    BuildContext context,
    List<String> walkingPlayers,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<SquadState>(
          builder: (context, squadState, child) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) {
                return AlertDialog(
                  backgroundColor: Colors.grey[850],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Rate Your Squad',
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold)),
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
                                'DEBUG: 12 RATING',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          ...walkingPlayers.map((player) {
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
                                        squadState
                                            .dailyRatings[player]!['Vibes']!
                                            .toDouble(),
                                        (value) => setDialogState(() {})),
                                    _buildSlider(
                                        'Comms',
                                        squadState
                                            .dailyRatings[player]!['Comms']!
                                            .toDouble(),
                                        (value) => setDialogState(() {})),
                                    _buildSlider(
                                        'Gunny',
                                        squadState
                                            .dailyRatings[player]!['Gunny']!
                                            .toDouble(),
                                        (value) => setDialogState(() {})),
                                    _buildSlider(
                                        'Wingman',
                                        squadState
                                            .dailyRatings[player]!['Wingman']!
                                            .toDouble(),
                                        (value) => setDialogState(() {})),
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
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Map<String, Map<String, int>> newRatings = {};
                        for (var player in walkingPlayers) {
                          newRatings[player] = {
                            'Vibes': squadState
                                .dailyRatings[player]!['Vibes']!,
                            'Comms': squadState
                                .dailyRatings[player]!['Comms']!,
                            'Gunny': squadState
                                .dailyRatings[player]!['Gunny']!,
                            'Wingman': squadState
                                .dailyRatings[player]!['Wingman']!,
                          };
                          // Update daily and all-time ratings
                          squadState.dailyRatings[player]!['Vibes'] = newRatings[player]!['Vibes']!;
                          squadState.dailyRatings[player]!['Comms'] = newRatings[player]!['Comms']!;
                          squadState.dailyRatings[player]!['Gunny'] = newRatings[player]!['Gunny']!;
                          squadState.dailyRatings[player]!['Wingman'] = newRatings[player]!['Wingman']!;
                          squadState.allTimeRatings[player]!['Vibes'] = newRatings[player]!['Vibes']!;
                          squadState.allTimeRatings[player]!['Comms'] = newRatings[player]!['Comms']!;
                          squadState.allTimeRatings[player]!['Gunny'] = newRatings[player]!['Gunny']!;
                          squadState.allTimeRatings[player]!['Wingman'] = newRatings[player]!['Wingman']!;
                        }
                        squadState.updateFirestore();
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
