import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:logger/logger.dart';
import '../providers.dart';
import '../presentation/notifiers/squad_notifier.dart' as sn;
import '../presentation/notifiers/user_notifier.dart';
import '../domain/entities/squad_state.dart';
import '../squad_tab/squad_tab.dart';
import '../app_theme.dart';
import '../squad_tab/dialogs/pin_game_dialog.dart';
import '../utils.dart';

class SquadTabScreen extends StatelessWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const SquadTabScreen(
      {super.key, this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  Widget build(BuildContext context) {
    return _SquadTabScreenContent(
        lobbyId: lobbyId,
        gameName: gameName,
        game: game,
        chatGroupId: chatGroupId);
  }
}

class _SquadTabScreenContent extends ConsumerStatefulWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const _SquadTabScreenContent(
      {this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  ConsumerState<_SquadTabScreenContent> createState() =>
      _SquadTabScreenContentState();
}

class _SquadTabScreenContentState
    extends ConsumerState<_SquadTabScreenContent> {
  final Logger _logger = Logger();
  late PageController _pageController;
  double _currentPage = 0.0;
  bool _hasActiveLobbies = false;

  @override
  void initState() {
    super.initState();
    _addViewerIfNeeded();
    _pageController = PageController(viewportFraction: 0.75);
    _pageController.addListener(() {
      final newPage = _pageController.page ?? 0.0;
      if (newPage.round() != _currentPage.round()) {
        // Haptic feedback on page snap
        HapticFeedback.lightImpact();
      }
      setState(() {
        _currentPage = newPage;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _removeViewerIfNeeded();
    super.dispose();
  }

  Future<void> _addViewerIfNeeded() async {
    if (widget.lobbyId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final squadManager = ref.read(squadManagerProvider);
        await squadManager.addViewer(widget.lobbyId!, user.uid);
      }
    }
  }

  Future<void> _removeViewerIfNeeded() async {
    if (widget.lobbyId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final squadManager = ref.read(squadManagerProvider);
        final squadState = ref.read(sn.squadNotifierProvider).value;
        if (squadState == null) return;

        // Check if user has a spot assigned
        final gameName = widget.gameName ?? '';
        final gameSquadSpots = squadState.gameSquadSpots[gameName] ?? [];
        final hasSpot = gameSquadSpots.contains(user.uid);

        // If user has a spot, remove them from filled list
        if (hasSpot) {
          await squadManager.leaveLobby(widget.lobbyId!, user.uid);
        }

        // Always remove from viewers
        await squadManager.removeViewer(widget.lobbyId!, user.uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final squadAsync = ref.watch(sn.squadNotifierProvider);
    return squadAsync.when(
      data: (squadState) {
        // If gameName is provided, show full squad management interface
        // (lobbyId is optional - SquadTab can handle showing spots for a game)
        if (widget.gameName != null) {
          return _buildFullSquadInterface(context, squadState);
        }

        // If no squad selected, show squad selection/dashboard instead of welcome screen
        if (squadState.selectedSquadId == null) {
          return _buildDashboardInterface(context, squadState, ref);
        }

        // Otherwise, show the dashboard with active lobbies
        return _buildDashboardInterface(context, squadState, ref);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showErrorSnackBar(context, 'Failed to load squad data: $error');
        });
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $error'),
                ElevatedButton(
                  onPressed: () => ref.invalidate(sn.squadNotifierProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboardInterface(
      BuildContext context, SquadState squadState, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Squad Lobbies'),
        backgroundColor: Colors.black,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.indigo],
          ),
        ),
        child: Column(
          children: [
            // Quick Join Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: QuickJoinButton(),
            ),
            // Active Lobbies Section (Top - contains lobbies and carousel)
            Expanded(
              child: _buildActiveLobbiesSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullSquadInterface(BuildContext context, SquadState squadState) {
    // Import and use the original SquadTab widget for full squad management
    return SquadTab(
        lobbyId: widget.lobbyId,
        gameName: widget.gameName,
        game: widget.game,
        chatGroupId: widget.chatGroupId);
  }

  Widget _buildActiveLobbiesSection(BuildContext context) {
    final squadManager = ref.read(squadManagerProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: StreamBuilder<QuerySnapshot>(
              stream: squadManager.getActiveLobbiesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading lobbies'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final peacocks = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final maxSpots = data['spots'] ?? 4;
                  final filled =
                      (data['filled'] as List<dynamic>?)?.length ?? 0;
                  final timer = data['timer'] as Timestamp?;
                  final isActive =
                      timer != null && timer.toDate().isAfter(DateTime.now());

                  return filled < maxSpots && isActive;
                }).toList();

                // Update layout based on active lobbies presence
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_hasActiveLobbies != peacocks.isNotEmpty) {
                    setState(() {
                      _hasActiveLobbies = peacocks.isNotEmpty;
                    });
                  }
                });

                return ListView(
                  children: [
                    // Game Select Section
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Game Select',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        return ref.watch(userNotifierProvider).when(
                              data: (userState) => _buildPinnedGamesCarousel(
                                  context, userState?.pinnedGames ?? [], ref),
                              loading: () => const SizedBox(),
                              error: (e, s) => const SizedBox(),
                            );
                      },
                    ),

                    // Active Lobbies Section
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Active Lobbies',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (peacocks.isNotEmpty) ...[
                      ...peacocks.map((doc) {
                        final peacock = doc.data() as Map<String, dynamic>;
                        final gameName =
                            peacock['game']?['name'] ?? 'Unknown Game';
                        final hostUid = peacock['hostUid'];
                        final maxSpots = peacock['spots'] ?? 4;
                        final filled =
                            (peacock['filled'] as List<dynamic>?)?.length ?? 0;
                        final filledList =
                            (peacock['filled'] as List<dynamic>?) ?? [];
                        final filledNames = filledList.map((uid) {
                          return ref
                              .read(sn.squadNotifierProvider.notifier)
                              .getDisplayNameForUid(uid.toString());
                        }).toList();
                        final isOwn = hostUid == user.uid;

                        return Container(
                          width: double.infinity,
                          height: 140,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Card(
                            color: Colors.white.withValues(alpha: 0.1),
                            child: InkWell(
                              onTap: () {
                                // Navigate to the squad screen for this lobby
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SquadTabScreen(
                                        lobbyId: doc.id,
                                        gameName: gameName,
                                        chatGroupId: widget.chatGroupId),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Left side: Game title and player names
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Game title
                                          Flexible(
                                            child: Text(
                                              gameName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Player names
                                          if (filledNames.isNotEmpty) ...[
                                            Flexible(
                                              child: Text(
                                                filledNames.join(', '),
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          // Action button
                                          SizedBox(
                                            height: 32,
                                            child: isOwn
                                                ? ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _closeLobby(
                                                            context, doc.id),
                                                    icon: const Icon(
                                                        Icons.close,
                                                        size: 12),
                                                    label: const Text('Close'),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.red.withValues(
                                                              alpha: 0.8),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                      textStyle:
                                                          const TextStyle(
                                                              fontSize: 10),
                                                    ),
                                                  )
                                                : ElevatedButton(
                                                    onPressed: () => _joinLobby(
                                                        context,
                                                        doc.id,
                                                        peacock),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 4),
                                                      textStyle:
                                                          const TextStyle(
                                                              fontSize: 11),
                                                    ),
                                                    child: const Text('Join'),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Right side: Big player count
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: Text(
                                          '$filled/$maxSpots',
                                          style: const TextStyle(
                                            color: Colors.cyanAccent,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ] else ...[
                      // Empty state when no active lobbies exist
                      Container(
                        height: 120,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Card(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.group_off,
                                  size: 32,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No active lobbies right now',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create one to get started!',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinnedGamesCarousel(BuildContext context,
      List<Map<String, dynamic>> pinnedGames, WidgetRef ref) {
    if (pinnedGames.isEmpty) {
      return Container(
        height: 450, // Increased by 10% from 409
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_border,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              'Pin favorites for quick access',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _startNewLobby(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Add "Add Game" card to the end of pinned games
    final allGames = [
      ...pinnedGames,
      {'isAddCard': true}
    ];
    final itemCount = allGames.length;
    final canSwipe = itemCount >= 2;

    return Column(
      children: [
        SizedBox(
          height: 450, // Increased by 10% from 409
          child: PageView.builder(
            controller: _pageController,
            itemCount: itemCount,
            physics: canSwipe
                ? const PageScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _buildLayeredCarouselItem(context, index, allGames, ref),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (canSwipe) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              itemCount,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage.round() == index ? 16 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage.round() == index
                      ? Colors.cyanAccent
                      : Colors.grey[600],
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: _currentPage.round() == index
                      ? [
                          BoxShadow(
                            color: Colors.cyanAccent.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLayeredCarouselItem(BuildContext context, int index,
      List<Map<String, dynamic>> games, WidgetRef ref) {
    final game = games[index];

    // Handle the "Add Game" card
    if (game['isAddCard'] == true) {
      final pageOffset = index - _currentPage;
      final isSelected = pageOffset.abs() < 0.5;
      final opacity = isSelected ? 1.0 : 0.7;
      final translateY = isSelected ? 0.0 : 8.0;

      return AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, translateY),
            child: Opacity(
              opacity: opacity,
              child: GestureDetector(
                onTap: () => _showPinGameDialog(context, ref),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 120,
                      height: 370, // Increased by 10% from 336
                      color: Colors.grey[800],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add,
                            color: Colors.cyanAccent,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add Game',
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    final pageOffset = index - _currentPage;

    // Simplified layering - tuck behind instead of complex animations
    final isSelected = pageOffset.abs() < 0.5;
    final opacity = isSelected ? 1.0 : 0.7;
    final translateY = isSelected ? 0.0 : 8.0; // Simple tuck behind effect

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: opacity,
            child: GestureDetector(
              onTap: () => _startLobbyForGame(context, game),
              onLongPress: () async {
                // Get the userManager from the Consumer context
                final userNotifier = ref.read(userNotifierProvider.notifier);
                await userNotifier.removePinnedGame(game['name']);
                // Show feedback that game was removed
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('${game['name']} removed from pinned games'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.cyanAccent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 120,
                    height: 370, // Increased by 10% from 336
                    child: game['coverUrl'] != null
                        ? CachedNetworkImage(
                            imageUrl: game['coverUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.cyanAccent),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.videogame_asset,
                                color: Colors.cyanAccent,
                                size: 32,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.videogame_asset,
                              color: Colors.cyanAccent,
                              size: 32,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPinGameDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const PinGameDialog(),
    );
  }

  void _startNewLobby(BuildContext context, WidgetRef ref) {
    final userState = ref.read(userNotifierProvider).value;

    final pinnedGames = userState?.pinnedGames ?? [];

    if (pinnedGames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No pinned games to choose from. Pin some games first!')),
      );
    } else {
      // Show game selection modal

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: AppTheme.darkTheme.scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    width: 40,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: pinnedGames.length,
                      itemBuilder: (context, index) {
                        final game = pinnedGames[index];

                        return ListTile(
                          leading: game['coverUrl'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: game['coverUrl'],
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.videogame_asset,
                                          size: 20),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.videogame_asset,
                                          size: 20),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.videogame_asset,
                                      color: Colors.cyanAccent),
                                ),
                          title: Text(
                            game['name'] ?? 'Unknown Game',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();

                            _startLobbyForGame(context, game);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  void _startLobbyForGame(
      BuildContext context, Map<String, dynamic> game) async {
    // Update lastPlayed for this game
    final userNotifier = ref.read(userNotifierProvider.notifier);
    userNotifier.updateGameLastPlayed(game['name']);

    // Directly create a lobby instead of showing the peacock modal
    await _createQuickStartLobby(context, game);
  }

  Future<void> _createQuickStartLobby(
      BuildContext context, Map<String, dynamic> game) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final gameName = game['name'];
    final maxSpots = game['maxSpots'] ?? 4;

    if (maxSpots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot create lobby for game with no spots')),
      );
      return;
    }

    final userState = ref.read(userNotifierProvider).value;
    final selectedCircle =
        'Squad'; // TODO: Implement alert circles in new architecture

    try {
      // Create peacock document in Firestore for lobby visibility
      final peacockData = {
        'hostUid': user.uid,
        'hostName': userState?.displayName ?? 'Unknown User',
        'game': {'name': gameName},
        'spots': maxSpots,
        'filled': [user.uid], // Creator auto-assigned to spot 1
        'viewers': <String>[], // Start with empty viewers list
        'timer':
            Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
        'createdAt': Timestamp.now(),
        'circle': selectedCircle,
      };

      final peacockRef = await FirebaseFirestore.instance
          .collection('peacocks')
          .add(peacockData);

      // Update user status to indicate they're looking for squad
      // Status updates are handled by the squad state management

      // Trigger notification
      final notificationManager = ref.read(notificationManagerProvider);
      notificationManager.showNotification(
        title: 'Game Lobby Created',
        body: 'Looking for $maxSpots spots in $gameName',
      );

      // Navigate to the squad tab for this game/lobby
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SquadTabScreen(
              lobbyId: peacockRef.id,
              gameName: gameName,
              game: game,
              chatGroupId: widget.chatGroupId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create game lobby: $e')),
      );
    }
  }

  void _joinLobby(BuildContext context, String peacockId,
      Map<String, dynamic> peacock) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final squadManager = ref.read(squadManagerProvider);

    // Join the lobby in Firestore
    await squadManager.joinLobby(peacockId, user.uid);

    // Also call a spot for the joining user to trigger timer logic
    final gameName = peacock['game']?['name'] ?? 'Unknown Game';
    try {
      // Find next available spot
      final filled = List<String>.from(peacock['filled'] ?? []);
      final maxSpots = peacock['spots'] ?? 4;
      int nextSpot = 0; // Start from 0 since creator is at spot 0
      while (filled.length > nextSpot && nextSpot < maxSpots) {
        nextSpot++;
      }

      if (nextSpot < maxSpots) {
        // Call the spot to trigger timer logic
        ref
            .read(sn.squadNotifierProvider.notifier)
            .callSpotForGame(nextSpot, gameName);
      }
    } catch (e) {
      // If spot calling fails, continue anyway
      _logger.e('Failed to call spot when joining lobby: $e');
    }

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Joined lobby!')),
    );
  }

  void _closeLobby(BuildContext context, String peacockId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final squadManager = ref.read(squadManagerProvider);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Lobby'),
        content: const Text(
            'Are you sure you want to close this lobby? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await squadManager.closeLobby(peacockId);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lobby closed successfully')),
        );
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close lobby: $e')),
        );
      }
    }
  }
}

class QuickJoinButton extends StatefulWidget {
  const QuickJoinButton({super.key});

  @override
  State<QuickJoinButton> createState() => _QuickJoinButtonState();
}

class _QuickJoinButtonState extends State<QuickJoinButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: ElevatedButton.icon(
          onPressed: () async {
            // Add haptic feedback
            HapticFeedback.lightImpact();

            final container = ProviderScope.containerOf(context);
            final userState = container.read(userNotifierProvider).value;
            final grokService = container.read(grokServiceProvider);
            final availabilityManager =
                container.read(availabilityManagerProvider);

            // Get pinned games
            final pinnedGames = userState?.pinnedGames ?? [];

            if (pinnedGames.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('No pinned games found. Pin some games first!')),
              );
              return;
            }

            // Show loading
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Getting suggestions from Grok...'),
                  ],
                ),
              ),
            );

            try {
              // Get Grok suggestions
              final grokResponse =
                  await grokService.suggestSquadsForPinnedGames(pinnedGames);

              // Get public lobbies
              final suggestedLobbies =
                  await availabilityManager.suggestLobbies(pinnedGames);

              // Close loading dialog
              Navigator.of(context).pop();

              // Show suggestions dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Quick Join Suggestions'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Grok says: $grokResponse'),
                        const SizedBox(height: 16),
                        const Text('Available Public Lobbies:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        ...suggestedLobbies.map((lobby) => ListTile(
                              title: Text(lobby['gameName'] ?? 'Unknown Game'),
                              subtitle: Text(
                                  'Spots: ${(lobby['filled'] as List?)?.length ?? 0}/${lobby['spots'] ?? 4}'),
                              onTap: () {
                                Navigator.of(context).pop();
                                // Navigate to the lobby
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => SquadTabScreen(
                                      lobbyId: lobby['id'],
                                      gameName: lobby['gameName'],
                                      game: {
                                        'name': lobby['gameName'],
                                        'maxSpots': lobby['spots'] ?? 4
                                      },
                                    ),
                                  ),
                                );
                              },
                            )),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            } catch (e) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to get suggestions: $e')),
              );
            }
          },
          icon: Icon(Icons.auto_awesome),
          label: const Text('Quick Join'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }
}
