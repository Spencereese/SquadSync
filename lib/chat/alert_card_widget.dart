import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../squad_state.dart';
import '../services/ai_service.dart';
import 'spots_sheet.dart';

class AlertCardWidget extends StatefulWidget {
  final String gameName;
  final String hostName;
  final int maxSpots;
  final String chatGroupId;
  final ChatType chatType;

  const AlertCardWidget({
    super.key,
    required this.gameName,
    required this.hostName,
    required this.maxSpots,
    required this.chatGroupId,
    required this.chatType,
  });

  @override
  _AlertCardWidgetState createState() => _AlertCardWidgetState();
}

class _AlertCardWidgetState extends State<AlertCardWidget> {
  late Stream<List<Map<String, dynamic>>> _peacockStatusStream;

  @override
  void initState() {
    super.initState();
    // Stream active peacock alerts for this game
    final squadState = Provider.of<SquadState>(context, listen: false);
    _peacockStatusStream = squadState.getActivePeacockAlerts(widget.gameName);
  }

  @override
  Widget build(BuildContext context) {
    final squadState = Provider.of<SquadState>(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _peacockStatusStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Error loading Peacock status: ${snapshot.error}')),
              );
            }
          });
          return SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 4,
            child: ListTile(
              title: Text('Loading alert...'),
              trailing: CircularProgressIndicator(),
            ),
          );
        }

        final activeStatuses = snapshot.data ?? [];
        if (activeStatuses.isEmpty) {
          return SizedBox.shrink();
        }

        // Use the first active alert for display
        final alert = activeStatuses.first;
        final hostName = alert['displayName'] ?? 'Someone';
        final maxSpots = alert['spots'] ?? 4;

        // Pull spots from SquadState
        final spots = squadState.gameSquadSpots[widget.gameName] ?? [];
        final occupiedSpots = spots.where((spot) => spot != null).length;
        final spotsLeft = maxSpots - occupiedSpots;

        return Card(
          elevation: 4,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () async {
              try {
                // Show spots sheet overlay
                SpotsSheet.show(
                  context,
                  gameName: widget.gameName,
                  maxSpots: maxSpots,
                  chatGroupId: widget.chatGroupId,
                  chatType: widget.chatType,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error opening spots: $e')),
                  );
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$hostName's ${widget.gameName}: $spotsLeft/$maxSpots spots left – Join?",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
