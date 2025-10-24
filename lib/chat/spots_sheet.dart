import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../squad_state.dart';
import '../managers/user_manager.dart';
import '../widgets/rating_widgets.dart';
import 'chat_service.dart';

class SpotsSheet extends StatefulWidget {
  final String gameName;
  final int maxSpots;
  final String chatGroupId;

  const SpotsSheet({
    super.key,
    required this.gameName,
    required this.maxSpots,
    required this.chatGroupId,
  });

  static void show(
    BuildContext context, {
    required String gameName,
    required int maxSpots,
    required String chatGroupId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SpotsSheet(
        gameName: gameName,
        maxSpots: maxSpots,
        chatGroupId: chatGroupId,
      ),
    );
  }

  @override
  State<SpotsSheet> createState() => _SpotsSheetState();
}

class _SpotsSheetState extends State<SpotsSheet> {
  bool _isClaiming = false;
  late RatingNudge _ratingNudge;

  @override
  void initState() {
    super.initState();
    _ratingNudge = RatingNudge(
      gameName: widget.gameName,
      chatGroupId: widget.chatGroupId,
      onRatingSubmitted: () {
        // Could add additional logic here if needed
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header with drag handle
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Consumer<SquadState>(
                  builder: (context, squadState, child) {
                    final spots =
                        squadState.gameSquadSpots[widget.gameName] ?? [];
                    final filledSpots =
                        spots.where((uid) => uid != null).length;
                    final names = spots
                        .where((uid) => uid != null)
                        .map((uid) => squadState.getDisplayNameForUid(uid!))
                        .join(', ');

                    return Text(
                      'Current: $names ($filledSpots/${widget.maxSpots} ${widget.gameName})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ],
            ),
          ),

          // Spots list
          Expanded(
            child: Consumer<SquadState>(
              builder: (context, squadState, child) {
                final spots = squadState.gameSquadSpots[widget.gameName] ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.maxSpots,
                  itemBuilder: (context, index) {
                    final isOccupied =
                        index < spots.length && spots[index] != null;
                    final spotValue = isOccupied ? spots[index] : null;
                    final isCalling = spotValue?.endsWith('_calling') ?? false;
                    final occupantUid = isCalling
                        ? spotValue!.replaceAll('_calling', '')
                        : spotValue;
                    final occupantName = occupantUid != null
                        ? squadState.getDisplayNameForUid(occupantUid)
                        : null;
                    final isCurrentUser =
                        occupantUid == FirebaseAuth.instance.currentUser?.uid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOccupied
                              ? (isCalling ? Colors.orange : Colors.cyanAccent)
                              : Colors.grey[700]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Spot ${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (isOccupied) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCalling
                                    ? Colors.orange.withOpacity(0.2)
                                    : Colors.cyanAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isCalling
                                    ? 'Calling'
                                    : (occupantName ?? 'Unknown'),
                                style: TextStyle(
                                  color: isCalling
                                      ? Colors.orange
                                      : Colors.cyanAccent,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (isCalling && isCurrentUser) ...[
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _lockSpot(index),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                child: const Text('Lock'),
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Rating nudge (only shown for first-time users)
          _ratingNudge,

          // FAB for claiming spot
          Container(
            padding: const EdgeInsets.all(16),
            child: FloatingActionButton.extended(
              onPressed: _isClaiming ? null : _claimSpot,
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              icon: _isClaiming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(_isClaiming ? 'Claiming...' : 'Claim Spot'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _claimSpot() async {
    final squadState = Provider.of<SquadState>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isClaiming = true);

    try {
      // Check current spots
      final spots = squadState.gameSquadSpots[widget.gameName] ?? [];
      final filledCount = spots.where((spot) => spot != null).length;

      if (filledCount >= widget.maxSpots) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Spots filled—next time!')),
          );
        }
        return;
      }

      // Find first available spot
      final availableIndex = spots.indexWhere((spot) => spot == null);
      if (availableIndex == -1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Spots filled—next time!')),
          );
        }
        return;
      }

      // Call the spot (set calling status)
      squadState.callSpotForGame(availableIndex, widget.gameName,
          maxSpots: widget.maxSpots);

      // Send message to chat thread
      final chatService = ChatService();
      final displayName = squadState.getDisplayNameForUid(user.uid);

      await chatService.sendMessage(
        context,
        senderUid: user.uid,
        text:
            '$displayName claimed spot ${availableIndex + 1} in ${widget.gameName}!',
        chatGroupId: widget.chatGroupId,
      );

      // Check if user has rated this game before
      final userManager = Provider.of<UserManager>(context, listen: false);
      if (!(userManager.hasRatedGame[widget.gameName] ?? false)) {
        // Show rating dialog after a brief delay to let the spot claim settle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => ReviewSubmitDialog(
                gameName: widget.gameName,
                chatGroupId: widget.chatGroupId,
              ),
            );
          }
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error claiming spot: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClaiming = false);
      }
    }
  }

  Future<void> _lockSpot(int index) async {
    final squadState = Provider.of<SquadState>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      squadState.lockCalledSpot(widget.gameName, index);

      // Send message to chat thread
      final chatService = ChatService();
      final displayName = squadState.getDisplayNameForUid(user.uid);

      await chatService.sendMessage(
        context,
        senderUid: user.uid,
        text: '$displayName locked spot ${index + 1} in ${widget.gameName}!',
        chatGroupId: widget.chatGroupId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spot locked!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error locking spot: $e')),
        );
      }
    }
  }
}
