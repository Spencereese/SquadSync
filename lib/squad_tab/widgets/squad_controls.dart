import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../squad_state.dart';

/// SquadControls component - handles action buttons and controls
/// Extracted from the monolithic SquadTab to improve maintainability
class SquadControls extends StatelessWidget {
  const SquadControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _WinButton(),
                _LossButton(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Win button widget - extracted for better performance
class _WinButton extends StatelessWidget {
  const _WinButton();

  @override
  Widget build(BuildContext context) {
    final squadState = Provider.of<SquadState>(context, listen: false);
    return ElevatedButton(
      onPressed: squadState.recordWin,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontSize: 18),
        elevation: 4,
        shadowColor: Colors.green.withValues(alpha: 0.3),
      ),
      child: const Text(
        'Win',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Loss button widget - extracted for better performance
class _LossButton extends StatelessWidget {
  const _LossButton();

  @override
  Widget build(BuildContext context) {
    final squadState = Provider.of<SquadState>(context, listen: false);
    return ElevatedButton(
      onPressed: squadState.recordLoss,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontSize: 18),
        elevation: 4,
        shadowColor: Colors.redAccent.withValues(alpha: 0.3),
      ),
      child: const Text(
        'Loss',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
