import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../lobbies_tab/widgets/clips_tab.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'clip_upload_dialog.dart';

/// Main clips screen for the navigation bar
/// Wraps the ClipsTab widget with proper app bar and context
class ClipsScreen extends ConsumerWidget {
  const ClipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

    return squadAsync.when(
      data: (squadState) {
        final squadId = squadState.selectedLobbyId;
        final gameColor = _getGameColor(squadState);

        return Scaffold(
          backgroundColor: const Color(0xFF0B0E14),
          appBar: AppBar(
            title: const Text('Clips'),
            backgroundColor: const Color(0xFF14181F),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.videocam),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => ClipUploadDialog(
                      squadId: squadId,
                      gameColor: gameColor,
                    ),
                  );
                },
                tooltip: 'Upload Clip',
              ),
            ],
          ),
          body: ClipsTab(
            squadId: squadId,
            gameColor: gameColor,
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading clips',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGameColor(dynamic squadState) {
    // Extract game color from current game or use default cyan
    // You can add logic to get color from game data
    return const Color(0xFF00FFFF);
  }
}
