import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'squad_queue_logic.dart';
import 'squad_queue_ui.dart';

class AvailabilityTab extends StatefulWidget {
  final SquadQueuePageState state;

  const AvailabilityTab({super.key, required this.state});

  @override
  AvailabilityTabState createState() => AvailabilityTabState();
}

class AvailabilityTabState extends State<AvailabilityTab> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  late tz.Location _userTimeZone;
  bool _isLoading = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    tz.initializeTimeZones();
    _userTimeZone = tz.getLocation(await _getUserTimeZone());
    await _loadEvents();
  }

  Future<String> _getUserTimeZone() async {
    // Implement logic to get user's actual timezone
    // For now, defaulting to America/New_York
    return 'America/New_York';
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .where('date',
              isGreaterThanOrEqualTo: DateTime.now()
                  .subtract(const Duration(days: 30))
                  .toIso8601String())
          .get();

      if (!mounted) return;
      setState(() {
        _events = {};
        for (var doc in snapshot.docs) {
          final data = doc.data();
          try {
            final date = DateTime.parse(data['date']);
            final event = {
              'player': data['player'] ?? 'Unknown',
              'available': data['available'] ?? false,
              'time': data['time'] ?? '00:00',
              'votes': data['votes'] ?? 0,
              'id': doc.id,
            };
            _events.update(
              DateTime(date.year, date.month, date.day),
              (list) => [...list, event],
              ifAbsent: () => [event],
            );
          } catch (e) {
            debugPrint('Error parsing event: $e');
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load events: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scheduleMatch(bool available) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final time = tz.TZDateTime.now(_userTimeZone);
      final currentPlayer =
          FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous';

      final event = {
        'player': currentPlayer,
        'available': available,
        'time': DateFormat('HH:mm').format(time),
        'date': _selectedDay.toIso8601String().split('T')[0],
        'votes': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('schedules').add(event);
      await _loadEvents();
      await _scheduleNotification(event);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability scheduled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _voteForEvent(Map<String, dynamic> event) async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('schedules').doc(event['id']);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Event not found');
        final newVotes = (snapshot.data()!['votes'] ?? 0) + 1;
        transaction.update(docRef, {'votes': newVotes});
      });
      await _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to vote: $e')),
        );
      }
    }
  }

  Future<void> _scheduleNotification(Map<String, dynamic> event) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'match_channel',
        'Match Notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      const platformDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        event.hashCode,
        'Match Scheduled',
        '${event['player']} is ${event['available'] ? 'available' : 'unavailable'} at ${event['time']}',
        tz.TZDateTime.from(_selectedDay, _userTimeZone)
            .add(const Duration(minutes: 5)),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
    }
  }

  List<FlSpot> _getHeatmapData() {
    final Map<int, int> dayCounts = {};
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    _events.forEach((date, events) {
      if (date.isAfter(startOfMonth)) {
        final day = date.day;
        dayCounts[day] = (dayCounts[day] ?? 0) + events.length;
      }
    });

    return dayCounts.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!mounted) return;
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    if (!mounted) return;
                    setState(() => _calendarFormat = format);
                  },
                  eventLoader: (day) =>
                      _events[DateTime(day.year, day.month, day.day)] ?? [],
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.cyanAccent,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _getHeatmapData(),
                        isCurved: true,
                        color: Colors.cyanAccent,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.cyanAccent.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_events[_selectedDay]?.isNotEmpty ?? false)
                ..._events[_selectedDay]!.map((event) => Card(
                      elevation: 1,
                      child: ListTile(
                        title: Text(
                          '${event['player']} - ${event['available'] ? 'Available' : 'Unavailable'}',
                          style: TextStyle(
                            color:
                                event['available'] ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${event['time']} | Votes: ${event['votes']}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.thumb_up,
                                  color: Colors.green),
                              onPressed: () => _voteForEvent(event),
                            ),
                            if (FirebaseAuth
                                    .instance.currentUser?.displayName ==
                                event['player'])
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('schedules')
                                      .doc(event['id'])
                                      .delete();
                                  await _loadEvents();
                                },
                              ),
                          ],
                        ),
                      ),
                    ))
              else
                const Center(child: Text('No events scheduled for this day')),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _scheduleMatch(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Set Available'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isLoading ? null : () => _scheduleMatch(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Set Unavailable'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
