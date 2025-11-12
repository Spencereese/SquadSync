import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../squad_state.dart';
import '../managers/squad_manager.dart';
import '../managers/user_manager.dart';
import '../managers/notification_manager.dart';
import '../chat/peacock_modal.dart';
import '../squad_tab/squad_tab.dart';

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

class _SquadTabScreenContent extends StatefulWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const _SquadTabScreenContent(
      {this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  _SquadTabScreenContentState createState() => _SquadTabScreenContentState();
}

class _SquadTabScreenContentState extends State<_SquadTabScreenContent> {
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
        final squadManager = Provider.of<SquadManager>(context, listen: false);
        await squadManager.addViewer(widget.lobbyId!, user.uid);
      }
    }
  }

  Future<void> _removeViewerIfNeeded() async {
    if (widget.lobbyId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final squadManager = Provider.of<SquadManager>(context, listen: false);
        final squadState = Provider.of<SquadState>(context, listen: false);

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
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        // If lobbyId and gameName are provided, show full squad management interface
        if (widget.lobbyId != null && widget.gameName != null) {
          return _buildFullSquadInterface(context, squadState);
        }

        // If no squad selected, show squad selection/dashboard instead of welcome screen
        if (squadState.selectedSquadId == null) {
          return _buildDashboardInterface(context, squadState);
        }

        // Otherwise, show the dashboard with active lobbies
        return _buildDashboardInterface(context, squadState);
      },
    );
  }

  Widget _buildDashboardInterface(BuildContext context, SquadState squadState) {
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
    final squadManager = Provider.of<SquadManager>(context, listen: false);
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
                    Consumer<UserManager>(
                      builder: (context, userManager, child) {
                        return _buildPinnedGamesCarousel(
                            context, userManager.pinnedGames);
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
                        final squadState =
                            Provider.of<SquadState>(context, listen: false);
                        final filledNames = filledList.map((uid) {
                          return squadState
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
                                          Text(
                                            gameName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          // Player names
                                          if (filledNames.isNotEmpty) ...[
                                            Text(
                                              filledNames.join(', '),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const Spacer(),
                                          // Action button
                                          isOwn
                                              ? const Text('Host',
                                                  style: TextStyle(
                                                      color: Colors.cyanAccent,
                                                      fontSize: 12))
                                              : ElevatedButton(
                                                  onPressed: () => _joinLobby(
                                                      context, doc.id, peacock),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                    textStyle: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                  child: const Text('Join'),
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

  Widget _buildPinnedGamesCarousel(
      BuildContext context, List<Map<String, dynamic>> pinnedGames) {
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
              onPressed: () => _startNewLobby(context),
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
                child: _buildLayeredCarouselItem(context, index, allGames),
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

  Widget _buildLayeredCarouselItem(
      BuildContext context, int index, List<Map<String, dynamic>> games) {
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
                onTap: () => _startNewLobby(context),
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
                final userManager =
                    Provider.of<UserManager>(context, listen: false);
                await userManager.removePinnedGame(game['name']);
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

  void _startNewLobby(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: const PeacockModal(),
      ),
    );
  }

  void _startLobbyForGame(
      BuildContext context, Map<String, dynamic> game) async {
    // Update lastPlayed for this game
    final userManager = Provider.of<UserManager>(context, listen: false);
    userManager.updateGameLastPlayed(game['name']);

    // Directly create a lobby instead of showing the peacock modal
    await _createQuickStartLobby(context, game);
  }

  Future<void> _createQuickStartLobby(
      BuildContext context, Map<String, dynamic> game) async {
    final squadState = Provider.of<SquadState>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final gameName = game['name'];
    final maxSpots = game['maxSpots'] ?? 4;
    final userManager = Provider.of<UserManager>(context, listen: false);
    final selectedCircle = userManager.alertCircles.first;

    try {
      // Set creator in spot 0 with 5-minute calling timer
      squadState.dataManager.gameSquadSpots[gameName] ??=
          List.filled(maxSpots, null);
      squadState.dataManager.gameSpotTimers[gameName] ??=
          List.filled(maxSpots, null);

      // Check if player is solo to determine timer duration
      final isSoloPlayer =
          squadState.isPlayingSolo(squadState.displayName ?? '');
      final timerDuration = isSoloPlayer
          ? 3600
          : 300; // 60 minutes for solo, 5 minutes for groups

      squadState.dataManager.gameSquadSpots[gameName]![0] =
          '${user.uid}_calling';
      squadState.dataManager.gameSpotTimers[gameName]![0] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': timerDuration, // Dynamic duration based on solo status
        'calling': true,
        'peacockCreated':
            true, // Flag to distinguish from regular calling spots
      };
      squadState.dataManager
              .globalStatuses[squadState.displayName ?? 'Unknown Player'] =
          'Calling';

      // Mark fields as changed for persistence
      squadState.persistenceManager.markFieldChanged('squadSpots');
      squadState.persistenceManager.markFieldChanged('spotTimers');
      squadState.persistenceManager.markFieldChanged('globalStatuses');
      squadState.uiManager.setNewSquadSpot(true, gameName);
      squadState.updateFirestoreAsync(force: true);

      // Create peacock document in Firestore for lobby visibility
      final peacockData = {
        'hostUid': user.uid,
        'hostName': squadState.displayName ?? 'Unknown Player',
        'game': {'name': gameName},
        'spots': maxSpots,
        'filled': [user.uid], // Creator auto-assigned to spot 1
        'viewers': <String>[], // Start with empty viewers list
        'timer': Timestamp.fromDate(
            DateTime.now().add(Duration(seconds: timerDuration))),
        'createdAt': Timestamp.now(),
        'circle': selectedCircle,
      };

      final peacockRef = await FirebaseFirestore.instance
          .collection('peacocks')
          .add(peacockData);

      // Update Firestore user doc
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'peacock': {
          'game': gameName,
          'spots': maxSpots,
          'timer': DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
          'circle': selectedCircle,
        }
      }, SetOptions(merge: true));

      // Update user status to indicate they're looking for squad
      squadState.dataManager.setStatus(user.uid, 'Looking for squad');

      // Trigger notification
      final notificationManager =
          Provider.of<NotificationManager>(context, listen: false);
      await notificationManager.showNotification(
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

    final squadManager = Provider.of<SquadManager>(context, listen: false);
    final squadState = Provider.of<SquadState>(context, listen: false);

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
        squadState.callSpotForGame(nextSpot, gameName);
      }
    } catch (e) {
      // If spot calling fails, continue anyway
      print('Failed to call spot when joining lobby: $e');
    }

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Joined lobby!')),
    );
  }
}
