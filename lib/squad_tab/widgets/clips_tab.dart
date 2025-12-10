import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/clip_notifier.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../../domain/entities/message.dart';
import 'clip_feed_item.dart';

/// Clips tab with infinite scroll feed
class ClipsTab extends ConsumerStatefulWidget {
  final String? squadId;
  final Color? gameColor;

  const ClipsTab({
    super.key,
    this.squadId,
    this.gameColor,
  });

  @override
  ConsumerState<ClipsTab> createState() => _ClipsTabState();
}

class _ClipsTabState extends ConsumerState<ClipsTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize clips stream
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final squadId = widget.squadId ??
          ref.read(ln.lobbyNotifierProvider).value?.selectedLobbyId;
      if (squadId != null) {
        ref.read(clipNotifierProvider.notifier).initializeClipsStream(squadId);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await ref.read(clipNotifierProvider.notifier).loadMoreClips();

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    await ref.read(clipNotifierProvider.notifier).refreshClips();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final clipStateAsync = ref.watch(clipNotifierProvider);

    return clipStateAsync.when(
      data: (clipState) {
        final clips = clipState.clips;
        final clipOfTheDay = clipState.clipOfTheDay;

        if (clips.isEmpty && clipOfTheDay == null) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          color: widget.gameColor ?? const Color(0xFF00FFFF),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Clip of the Day section
              if (clipOfTheDay != null)
                SliverToBoxAdapter(
                  child: _buildClipOfTheDay(clipOfTheDay, clips),
                ),

              // Clips feed
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final clip = clips[index];
                    final squadId = widget.squadId ??
                        ref
                            .read(ln.lobbyNotifierProvider)
                            .value
                            ?.selectedLobbyId;

                    return ClipFeedItem(
                      messageData: clip,
                      chatGroupId: squadId ?? '',
                      chatType: ChatType.squad,
                      gameColor: widget.gameColor,
                      allClips: clips,
                      onView: () {
                        ref
                            .read(clipNotifierProvider.notifier)
                            .markClipAsViewed(clip.id);
                      },
                    );
                  },
                  childCount: clips.length,
                ),
              ),

              // Loading indicator at bottom
              if (clipState.isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.gameColor ?? const Color(0xFF00FFFF),
                        ),
                      ),
                    ),
                  ),
                ),

              // End of list indicator
              if (!clipState.hasMore && clips.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'You\'ve reached the end 🎮',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),

              // Bottom spacing
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.gameColor ?? const Color(0xFF00FFFF),
          ),
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Failed to load clips',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.gameColor ?? const Color(0xFF00FFFF),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: widget.gameColor ?? const Color(0xFF00FFFF),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 80,
                    color: widget.gameColor ?? const Color(0xFF00FFFF),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No clips yet... drop the first one 🔥',
                    style: TextStyle(
                      color: widget.gameColor ?? const Color(0xFF00FFFF),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                      shadows: [
                        Shadow(
                          color: (widget.gameColor ?? const Color(0xFF00FFFF))
                              .withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your best gaming moments',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClipOfTheDay(clip, allClips) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (widget.gameColor ?? const Color(0xFF00FFFF)).withOpacity(0.2),
            Colors.black.withOpacity(0.3),
          ],
        ),
        border: Border.all(
          color: widget.gameColor ?? const Color(0xFF00FFFF),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (widget.gameColor ?? const Color(0xFF00FFFF)).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: widget.gameColor ?? const Color(0xFF00FFFF),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'CLIP OF THE DAY',
                  style: TextStyle(
                    color: widget.gameColor ?? const Color(0xFF00FFFF),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Clip content
          ClipFeedItem(
            messageData: clip,
            chatGroupId: widget.squadId ??
                ref.read(ln.lobbyNotifierProvider).value?.selectedLobbyId ??
                '',
            chatType: ChatType.squad,
            gameColor: widget.gameColor,
            allClips: allClips,
            onView: () {
              ref.read(clipNotifierProvider.notifier).markClipAsViewed(clip.id);
            },
          ),
        ],
      ),
    );
  }
}
