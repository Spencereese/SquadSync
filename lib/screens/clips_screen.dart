import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifiers/game_notifier.dart';
import '../lobbies_tab/widgets/clips_tab.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'clip_upload_dialog.dart';

/// Main clips screen for the navigation bar with lazy loading and Twitch integration
/// Wraps the ClipsTab widget with proper app bar and context
class ClipsScreen extends ConsumerStatefulWidget {
  const ClipsScreen({super.key});

  @override
  ConsumerState<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends ConsumerState<ClipsScreen> {
  bool _showTwitchClips = false;

  @override
  void initState() {
    super.initState();
    // Preload Twitch clips when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameNotifier = ref.read(gameNotifierProvider.notifier);
      gameNotifier.fetchTrendingClips(limit: 20, period: 'day');
    });
  }

  @override
  Widget build(BuildContext context) {
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);
    final gameAsync = ref.watch(gameNotifierProvider);

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
              // Toggle Twitch clips view
              IconButton(
                icon: Icon(
                  _showTwitchClips ? Icons.people : Icons.celebration,
                  color: _showTwitchClips ? gameColor : Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _showTwitchClips = !_showTwitchClips;
                  });
                  if (_showTwitchClips) {
                    ref
                        .read(gameNotifierProvider.notifier)
                        .fetchTrendingClips();
                  }
                },
                tooltip: _showTwitchClips ? 'Squad Clips' : 'Trending Clips',
              ),
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
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: _showTwitchClips
                ? _buildTwitchClipsView(gameAsync, gameColor)
                : ClipsTab(
                    squadId: squadId,
                    gameColor: gameColor,
                  ),
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

  Widget _buildTwitchClipsView(
      AsyncValue<GameState> gameAsync, Color gameColor) {
    return gameAsync.when(
      data: (gameState) {
        final clips = gameState.twitchClips;

        if (clips.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.celebration_outlined,
                  size: 80,
                  color: gameColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'No trending clips available',
                  style: TextStyle(
                    color: gameColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ref
                        .read(gameNotifierProvider.notifier)
                        .fetchTrendingClips();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gameColor,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(gameNotifierProvider.notifier).fetchTrendingClips();
          },
          color: gameColor,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: clips.length,
            itemBuilder: (context, index) {
              final clip = clips[index];
              return _buildTwitchClipCard(clip, gameColor);
            },
          ),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(gameColor),
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load Twitch clips',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwitchClipCard(Map<String, dynamic> clip, Color gameColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF14181F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: gameColor.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () {
          // Open clip URL in external browser or embedded player
          // TODO: Implement clip playback
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            if (clip['thumbnailUrl'] != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  clip['thumbnailUrl'],
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.black26,
                      child: const Icon(Icons.broken_image, size: 48),
                    );
                  },
                ),
              ),

            // Clip info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clip['title'] ?? 'Untitled Clip',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: gameColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          clip['broadcasterName'] ?? 'Unknown',
                          style: TextStyle(
                            color: gameColor,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.visibility, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        '${clip['viewCount'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (clip['duration'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.timer, size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '${clip['duration']}s',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
