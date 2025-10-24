import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../squad_state.dart';
import '../squad_tab/squad_dialogs.dart';
import '../no_squad_screen.dart';
import '../managers/squad_manager.dart';
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
  @override
  void initState() {
    super.initState();
    _addViewerIfNeeded();
  }

  @override
  void dispose() {
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
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/images/settings_gear.png',
              width: 28,
              height: 28,
              color: Colors.grey[400],
            ),
            onPressed: () =>
                SquadDialogs.showSettingsDialog(context, squadState),
            tooltip: 'Settings',
          ),
        ],
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No active games—start one?',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _startNewLobby(context),
                          child: const Text(
                            'Tap the + button below',
                            style: TextStyle(color: Colors.cyanAccent),
                          ),
                        ),
                      ],
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
                    final timer = peacock['timer'] as Timestamp?;
                    final isOwn = hostUid == user.uid;

                    String title = isOwn
                        ? 'Your $gameName Lobby'
                        : '$hostName\'s $gameName';
                    String timerText = '';
                    if (timer != null) {
                      final now = Timestamp.now();
                      final diff = timer.seconds - now.seconds;
                      if (diff > 0) {
                        final minutes = (diff / 60).ceil();
                        timerText = ' • $minutes min left';
                      }
                    }

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
                          '$filled/$maxSpots spots filled$timerText • $viewers viewers',
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

  void _startNewLobby(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PeacockModal(),
    );
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
