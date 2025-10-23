import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../squad_state.dart';
import '../managers/user_manager.dart';
import '../managers/notification_manager.dart';

class PeacockModal extends StatefulWidget {
  const PeacockModal({super.key});

  @override
  _PeacockModalState createState() => _PeacockModalState();
}

class _PeacockModalState extends State<PeacockModal> {
  final TextEditingController _gameController = TextEditingController();
  double _spots = 4;
  String? _selectedCircle;
  bool _alertBackups = false;
  bool _isLoading = false;
  Map<String, dynamic>? _selectedGame;

  @override
  void initState() {
    super.initState();
    _selectedCircle =
        Provider.of<UserManager>(context, listen: false).alertCircles.first;
    // Fetch pinned games
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userManager = Provider.of<UserManager>(context, listen: false);
      userManager.fetchPinnedGames();
    });
  }

  @override
  void dispose() {
    _gameController.dispose();
    super.dispose();
  }

  Future<void> _submitPeacock() async {
    if (_gameController.text.isEmpty || _selectedCircle == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final squadState = Provider.of<SquadState>(context, listen: false);
      final gameName = _gameController.text;

      // Init gameSpotTimers in SquadManager
      squadState.dataManager.gameSpotTimers[gameName] ??=
          List.filled(_spots.toInt(), null);

      // Create peacock document in Firestore for lobby visibility
      final peacockData = {
        'hostUid': user.uid,
        'hostName': squadState.displayName ?? 'Unknown Player',
        'game': {'name': gameName},
        'spots': _spots.toInt(),
        'filled': [user.uid], // Creator auto-assigned to spot 1
        'viewers': <String>[], // Start with empty viewers list
        'timer':
            Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
        'createdAt': Timestamp.now(),
        'circle': _selectedCircle,
      };

      await FirebaseFirestore.instance.collection('peacocks').add(peacockData);

      // Update Firestore user doc
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'peacock': {
          'game': gameName,
          'spots': _spots.toInt(),
          'timer': DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
          'circle': _selectedCircle,
        }
      }, SetOptions(merge: true));

      // Update user status to indicate they're looking for squad
      squadState.dataManager.setStatus(user.uid, 'Looking for squad');

      // Trigger notification
      final notificationManager =
          Provider.of<NotificationManager>(context, listen: false);
      await notificationManager.showNotification(
        title: 'Peacock Alert',
        body: 'Looking for ${_spots.toInt()} spots in $gameName',
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create peacock: $e')),
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
    final userManager = Provider.of<UserManager>(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.85, 1.0],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with icon, title, and close button
                      Row(
                        children: [
                          const Icon(Icons.flash_on, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Start a Squad',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Pinned games section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pinned Games',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (userManager.pinnedGames.isEmpty)
                            Container(
                              height: 80,
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Pin favorites for quick access',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          else
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: userManager.pinnedGames.length,
                                itemBuilder: (context, index) {
                                  final game = userManager.pinnedGames[index];
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _gameController.text =
                                            game['name'] ?? '';
                                        _selectedGame = game;
                                        if (game['maxSpots'] != null) {
                                          _spots = (game['maxSpots'] as int)
                                              .toDouble();
                                        }
                                      });
                                      // Haptic feedback
                                      HapticFeedback.lightImpact();
                                    },
                                    child: Container(
                                      width: 70,
                                      margin: const EdgeInsets.only(right: 8),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                image: game['coverUrl'] != null
                                                    ? DecorationImage(
                                                        image:
                                                            CachedNetworkImageProvider(
                                                                game[
                                                                    'coverUrl']),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                                color: Colors.grey[300],
                                              ),
                                              child: game['coverUrl'] == null
                                                  ? const Icon(Icons.gamepad)
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            game['name'] ?? '',
                                            style:
                                                const TextStyle(fontSize: 10),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      // Game input at the top
                      TextField(
                        controller: _gameController,
                        decoration: const InputDecoration(
                          labelText: 'Game',
                          hintText: 'Enter game name...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Selected game preview
                      if (_selectedGame != null)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              if (_selectedGame!['coverUrl'] != null)
                                CachedNetworkImage(
                                  imageUrl: _selectedGame!['coverUrl'],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 50),
                                  ),
                                )
                              else
                                Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.gamepad, size: 50),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedGame!['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_selectedGame!['genres'] != null)
                                      Text(
                                        (_selectedGame!['genres']
                                                as List<dynamic>)
                                            .join(', '),
                                        style:
                                            const TextStyle(color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_selectedGame != null) const SizedBox(height: 16),
                      // Max spots display
                      if (_selectedGame != null &&
                          _selectedGame!['maxSpots'] != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Max spots: ${_selectedGame!['maxSpots']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_selectedGame != null &&
                          _selectedGame!['maxSpots'] != null)
                        const SizedBox(height: 16),
                      // Spots slider
                      Row(
                        children: [
                          const Text('Spots:'),
                          Expanded(
                            child: Slider(
                              value: _spots,
                              min: 1,
                              max: _selectedGame?['maxSpots']?.toDouble() ?? 6,
                              divisions:
                                  ((_selectedGame?['maxSpots']?.toDouble() ??
                                              6) -
                                          1)
                                      .toInt(),
                              label: _spots.toInt().toString(),
                              onChanged: (value) =>
                                  setState(() => _spots = value),
                            ),
                          ),
                          Text(_spots.toInt().toString()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Circle dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCircle,
                        decoration: const InputDecoration(
                          labelText: 'Circle',
                          border: OutlineInputBorder(),
                        ),
                        items: userManager.alertCircles.map((circle) {
                          return DropdownMenuItem(
                              value: circle, child: Text(circle));
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCircle = value),
                      ),
                      const SizedBox(height: 16),
                      // Alert backups checkbox
                      CheckboxListTile(
                        title:
                            const Text('Alert backups if unfilled after 5min'),
                        value: _alertBackups,
                        onChanged: (value) =>
                            setState(() => _alertBackups = value ?? false),
                      ),
                      const SizedBox(height: 24),
                      // Launch button
                      ElevatedButton(
                        onPressed: (_isLoading ||
                                _gameController.text.isEmpty ||
                                _selectedCircle == null)
                            ? null
                            : _submitPeacock,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Launch Squad',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
