import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../squad_state.dart';
import '../no_squad_screen.dart';
import '../managers/squad_manager.dart';
import '../managers/user_manager.dart';
import '../managers/notification_manager.dart';
import '../chat/peacock_modal.dart';
import '../squad_tab/squad_tab.dart';

class SquadTabScreen extends StatelessWidget {
  final String? lobbyId;
  final String? gameName;

  const SquadTabScreen({super.key, this.lobbyId, this.gameName});

  @override
  Widget build(BuildContext context) {
    return _SquadTabScreenContent(lobbyId: lobbyId, gameName: gameName);
  }
}

class _SquadTabScreenContent extends StatefulWidget {
  final String? lobbyId;
  final String? gameName;

  const _SquadTabScreenContent({this.lobbyId, this.gameName});

  @override
  _SquadTabScreenContentState createState() => _SquadTabScreenContentState();
}

class _SquadTabScreenContentState extends State<_SquadTabScreenContent> {
  late PageController _pageController;
  double _currentPage = 0.0;

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
        await squadManager.removeViewer(widget.lobbyId!, user.uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        if (squadState.selectedSquadId == null) {
          return const NoSquadScreen();
        }

        // If lobbyId and gameName are provided, show full squad management interface
        if (widget.lobbyId != null && widget.gameName != null) {
          return _buildFullSquadInterface(context, squadState);
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
            // Active Lobbies Section (Top Half)
            Expanded(
              flex: 1,
              child: _buildActiveLobbiesSection(context),
            ),
            // Member Status Section (Bottom Half)
            Expanded(
              flex: 1,
              child: _buildMemberStatusSection(context, squadState),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startNewLobby(context),
        backgroundColor: Colors.cyanAccent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFullSquadInterface(BuildContext context, SquadState squadState) {
    // Import and use the original SquadTab widget for full squad management
    return SquadTab(lobbyId: widget.lobbyId, gameName: widget.gameName);
  }

  Widget _buildActiveLobbiesSection(BuildContext context) {
    final squadManager = Provider.of<SquadManager>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Active Lobbies',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.cyanAccent, fontWeight: FontWeight.bold),
          ),
        ),
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
                  return filled < maxSpots;
                }).toList();

                if (peacocks.isEmpty) {
                  return Consumer<UserManager>(
                    builder: (context, userManager, child) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'No active games',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          if (userManager.pinnedGames.isNotEmpty) ...[
                            const Text(
                              'Quick Start:',
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPinnedGamesCarousel(
                                context, userManager.pinnedGames),
                          ] else ...[
                            const Text(
                              'Pin favorites for quick start',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: peacocks.length,
                  itemBuilder: (context, index) {
                    final peacock =
                        peacocks[index].data() as Map<String, dynamic>;
                    final gameName = peacock['game']?['name'] ?? 'Unknown Game';
                    final hostName = peacock['hostName'] ?? 'Unknown Host';
                    final hostUid = peacock['hostUid'];
                    final maxSpots = peacock['spots'] ?? 4;
                    final filled =
                        (peacock['filled'] as List<dynamic>?)?.length ?? 0;
                    final viewers =
                        (peacock['viewers'] as List<dynamic>?)?.length ?? 0;
                    final isOwn = hostUid == user.uid;

                    String title = isOwn
                        ? 'Your $gameName Lobby'
                        : '$hostName\'s $gameName Lobby: $filled/$maxSpots spots';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      color: Colors.white.withValues(alpha: 0.1),
                      child: ListTile(
                        title: Text(
                          title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '$viewers viewers',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: isOwn
                            ? const Text('Yours',
                                style: TextStyle(color: Colors.cyanAccent))
                            : ElevatedButton(
                                onPressed: () => _joinLobby(
                                    context, peacocks[index].id, peacock),
                                child: const Text('Join'),
                              ),
                        onTap: () =>
                            _enterLobby(context, peacocks[index].id, peacock),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberStatusSection(
      BuildContext context, SquadState squadState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Member Status',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.cyanAccent, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: squadState.getFilteredMembers.isEmpty
              ? const Center(
                  child: Text(
                    'No squad members yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: squadState.getFilteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = squadState.getFilteredMembers[index];
                    return _buildMemberStatusCard(context, member, squadState);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMemberStatusCard(
      BuildContext context, String member, SquadState squadState) {
    // For now, show basic status - can be enhanced with actual online/activity status
    String statusText = 'Member';
    Color statusColor = Colors.white70;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.white.withValues(alpha: 0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.cyanAccent,
          child: Text(
            member.isNotEmpty ? member[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          member,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          statusText,
          style: TextStyle(color: statusColor),
        ),
        trailing: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedGamesCarousel(
      BuildContext context, List<Map<String, dynamic>> pinnedGames) {
    if (pinnedGames.isEmpty) {
      return Container(
        height: 160,
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
              'Pin favorites for quick start',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final itemCount = pinnedGames.length;
    final canSwipe = itemCount >= 2;

    return Column(
      children: [
        SizedBox(
          height: 180, // Increased height for layered effect
          child: PageView.builder(
            controller: _pageController,
            itemCount: itemCount,
            physics: canSwipe
                ? const PageScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return _buildLayeredCarouselItem(context, index, pinnedGames);
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
      BuildContext context, int index, List<Map<String, dynamic>> pinnedGames) {
    final game = pinnedGames[index];
    final pageOffset = index - _currentPage;

    // Calculate layered positioning values
    final isSelected = pageOffset.abs() < 0.5;
    final isAdjacent = pageOffset.abs() >= 0.5 && pageOffset.abs() < 1.5;

    // Scale: selected = 1.1, adjacent = 0.85-0.95, far = 0.8
    final scale = isSelected
        ? 1.1 - (pageOffset.abs() * 0.1).clamp(0.0, 0.2)
        : isAdjacent
            ? 0.9 - (pageOffset.abs() - 0.5) * 0.1
            : 0.8;

    // Vertical offset: selected = 0, adjacent = -10px, far = -20px
    final translateY = isSelected
        ? 0.0
        : isAdjacent
            ? -8.0 - ((pageOffset.abs() - 0.5) * 4.0)
            : -16.0;

    // Opacity: selected = 1.0, adjacent = 0.9, far = 0.7
    final opacity = isSelected
        ? 1.0
        : isAdjacent
            ? 0.85 - ((pageOffset.abs() - 0.5) * 0.1)
            : 0.7;

    // Elevation: selected = 8, adjacent = 4, far = 2
    final elevation = isSelected
        ? 8.0 - (pageOffset.abs() * 4.0).clamp(0.0, 6.0)
        : isAdjacent
            ? 4.0 - ((pageOffset.abs() - 0.5) * 2.0)
            : 2.0;

    // Horizontal offset for adjacent cards (20% width peek)
    final horizontalOffset = pageOffset > 0
        ? pageOffset * 40.0 // Right side
        : pageOffset * 40.0; // Left side

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(horizontalOffset, translateY),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: GestureDetector(
                onTap: () => _startLobbyForGame(context, game),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.grey[800]!.withValues(alpha: 0.9),
                        Colors.grey[900]!.withValues(alpha: 0.95),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: elevation,
                        offset: Offset(0, elevation * 0.5),
                      ),
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.1),
                        blurRadius: elevation * 2,
                        offset: Offset(0, elevation * 0.25),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Game logo/image
                          SizedBox(
                            width: 80 * scale.clamp(0.8, 1.1),
                            height: 80 * scale.clamp(0.8, 1.1),
                            child: game['coverUrl'] != null
                                ? CachedNetworkImage(
                                    imageUrl: game['coverUrl'],
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        const CircularProgressIndicator(
                                            strokeWidth: 2),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.gamepad,
                                      size: 40 * scale.clamp(0.8, 1.1),
                                      color: Colors.cyanAccent,
                                    ),
                                  )
                                : Icon(
                                    Icons.videogame_asset,
                                    size: 40 * scale.clamp(0.8, 1.1),
                                    color: Colors.cyanAccent,
                                  ),
                          ),
                          const SizedBox(height: 12),
                          // Game name
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              game['name'] ?? 'Unknown',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16 * scale.clamp(0.8, 1.1),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
      builder: (context) => const PeacockModal(),
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

      squadState.dataManager.gameSquadSpots[gameName]![0] =
          '${user.uid}_calling';
      squadState.dataManager.gameSpotTimers[gameName]![0] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': 300, // 5 minutes for lobby creator
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
        'timer':
            Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
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
        title: 'Quick Start Lobby Created',
        body: 'Looking for $maxSpots spots in $gameName',
      );

      // Navigate to the squad tab for this game/lobby
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SquadTabScreen(lobbyId: peacockRef.id, gameName: gameName),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create Quick Start lobby: $e')),
      );
    }
  }

  void _joinLobby(BuildContext context, String peacockId,
      Map<String, dynamic> peacock) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final squadManager = Provider.of<SquadManager>(context, listen: false);
    await squadManager.joinLobby(peacockId, user.uid);

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Joined lobby!')),
    );
  }

  void _enterLobby(
      BuildContext context, String peacockId, Map<String, dynamic> peacock) {
    final gameName = peacock['game']?['name'] ?? '';

    // Navigate to full SquadTabScreen filtered for this lobby's game
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SquadTabScreen(lobbyId: peacockId, gameName: gameName),
      ),
    );
  }
}
