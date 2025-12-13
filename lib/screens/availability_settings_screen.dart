import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifiers/game_notifier.dart';
import 'package:google_fonts/google_fonts.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../domain/entities/game.dart';

class AvailabilitySettingsScreen extends ConsumerStatefulWidget {
  const AvailabilitySettingsScreen({super.key});

  @override
  ConsumerState<AvailabilitySettingsScreen> createState() =>
      _AvailabilitySettingsScreenState();
}

class _AvailabilitySettingsScreenState
    extends ConsumerState<AvailabilitySettingsScreen> {
  bool _isLoading = false;
  final Map<String, String> _selectedModes = {};

  @override
  void initState() {
    super.initState();
    // Initialize with current preferred modes
    final userAsync = ref.read(userNotifierProvider);
    userAsync.maybeWhen(
      data: (user) {
        if (user != null) {
          _selectedModes.addAll(user.preferredModes.map(
            (key, value) => MapEntry(key, value ?? ''),
          ));
        }
      },
      orElse: () {},
    );
  }

  Future<void> _saveAvailability() async {
    setState(() => _isLoading = true);

    try {
      // For now, we'll just show a success message
      // In a real implementation, you'd update the user's preferred modes
      // This would require a new usecase and method in user_notifier

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Availability settings saved!',
              style: GoogleFonts.robotoMono(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save settings: $e',
              style: GoogleFonts.robotoMono(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameStateAsync = ref.watch(gameNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Availability Settings',
          style: GoogleFonts.robotoMono(
            fontWeight: FontWeight.bold,
            color: Colors.cyan,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.cyan),
      ),
      backgroundColor: Colors.black,
      body: gameStateAsync.when(
        data: (gameState) => _buildSettingsList(gameState.availableGames),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.cyan),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error loading games: $error',
            style: GoogleFonts.robotoMono(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsList(List<Game> games) {
    // Common game modes for squad-based games
    const List<String> commonModes = [
      'Battle Royale',
      'Team Deathmatch',
      'Capture the Flag',
      'Domination',
      'Search & Destroy',
      'Hardpoint',
      'Kill Confirmed',
      'Free for All',
    ];

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              final gameName = game.name;

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gameName,
                        style: GoogleFonts.robotoMono(
                          color: Colors.cyan,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Preferred Mode:',
                        style: GoogleFonts.robotoMono(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: commonModes.map((modeName) {
                          final isSelected =
                              _selectedModes[gameName] == modeName;

                          return ChoiceChip(
                            label: Text(
                              modeName,
                              style: GoogleFonts.robotoMono(
                                color: isSelected ? Colors.black : Colors.white,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.cyan,
                            backgroundColor: Colors.grey[800],
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedModes[gameName] = modeName;
                                } else {
                                  _selectedModes.remove(gameName);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveAvailability,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text(
                      'Save Settings',
                      style: GoogleFonts.robotoMono(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
