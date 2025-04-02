import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AvailabilityTab extends StatefulWidget {
  final dynamic state;

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
        final currentUser = FirebaseAuth.instance.currentUser;
        final currentUid = currentUser?.uid ?? 'anonymous';
        final currentDisplayName = currentUser?.displayName ?? 'Anonymous';

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final date = DateTime.parse(data['date']);
          final player = data['player'] ?? 'Unknown';
          final event = {
            'player': player,
            'startTime': data['startTime'] ?? '00:00',
            'endTime': data['endTime'] ?? '23:59',
            'votes': data['votes'] ?? 0,
            'id': doc.id,
            'recurring': data['recurring'] ?? false,
            'recurringDays': data['recurringDays'] ?? [],
            'allDay': data['allDay'] ?? false,
            'displayName': data['displayName'] ?? player,
          };
          _events.update(
            DateTime(date.year, date.month, date.day),
            (list) => [...list, event],
            ifAbsent: () => [event],
          );

          // Migrate old data: if player is displayName and not UID, update it
          if (player == currentDisplayName && player != currentUid) {
            print(
                'Migrating schedule ${doc.id}: player $player -> $currentUid');
            doc.reference.update(
                {'player': currentUid, 'displayName': currentDisplayName});
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scheduleAvailabilityDialog() async {
    DateTime startTime = DateTime.now();
    DateTime endTime = DateTime.now().add(const Duration(hours: 1));
    bool isAllDay = false;
    bool isRecurring = false;
    List<bool> recurringDays = [
      false,
      true,
      true,
      true,
      true,
      true,
      false
    ]; // Mon-Fri default
    bool inviteSquad = false;
    String? inviteMember;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule Your Availability'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('All Day?',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: isAllDay,
                      onChanged: (value) =>
                          setDialogState(() => isAllDay = value),
                      activeColor: Colors.cyanAccent,
                    ),
                  ],
                ),
                if (!isAllDay) ...[
                  const Text('Start Time',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(
                    height: 100,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: startTime,
                      onDateTimeChanged: (value) =>
                          setDialogState(() => startTime = value),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('End Time',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(
                    height: 100,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: endTime,
                      onDateTimeChanged: (value) =>
                          setDialogState(() => endTime = value),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Repeat Weekly?',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: isRecurring,
                      onChanged: (value) =>
                          setDialogState(() => isRecurring = value),
                      activeColor: Colors.cyanAccent,
                    ),
                  ],
                ),
                if (isRecurring || isAllDay)
                  Wrap(
                    spacing: 8,
                    children: List.generate(
                        7,
                        (index) => ChoiceChip(
                              label: Text(
                                  ['S', 'M', 'T', 'W', 'T', 'F', 'S'][index]),
                              selected: recurringDays[index],
                              onSelected: (selected) => setDialogState(
                                  () => recurringDays[index] = selected),
                            )),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Invite Squad?',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: inviteSquad,
                      onChanged: (value) =>
                          setDialogState(() => inviteSquad = value),
                    ),
                  ],
                ),
                if (!inviteSquad)
                  DropdownButton<String>(
                    hint: const Text('Invite a Member'),
                    value: inviteMember,
                    items: [
                      'Player1',
                      'Player2',
                      'Player3'
                    ] // Replace with squad list
                        .map((member) => DropdownMenuItem(
                            value: member, child: Text(member)))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => inviteMember = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Set'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be signed in to schedule availability.');
      }
      final playerUid = currentUser.uid;
      final displayName = currentUser.displayName ?? 'Anonymous';
      print(
          'Scheduling as UID: $playerUid, DisplayName: $displayName'); // Debug

      final startTimeOfDay = TimeOfDay.fromDateTime(startTime);
      final endTimeOfDay = TimeOfDay.fromDateTime(endTime);

      if (isRecurring || isAllDay) {
        final startDate = _selectedDay;
        for (int i = 0; i < 30; i++) {
          final date = startDate.add(Duration(days: i));
          if (recurringDays[date.weekday % 7]) {
            await _addEvent(
                date,
                playerUid,
                displayName,
                isAllDay ? null : startTimeOfDay,
                isAllDay ? null : endTimeOfDay,
                isRecurring,
                recurringDays,
                isAllDay);
          }
        }
      } else {
        await _addEvent(_selectedDay, playerUid, displayName, startTimeOfDay,
            endTimeOfDay, false, [], isAllDay);
      }

      await _loadEvents();
      if (!isAllDay) {
        await _scheduleNotification(startTimeOfDay, endTimeOfDay);
      }

      if (inviteSquad || inviteMember != null) {
        await _sendInvites(displayName, inviteSquad ? 'Squad' : inviteMember!,
            isAllDay, startTimeOfDay, endTimeOfDay);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability scheduled!')),
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

  Future<void> _addEvent(
      DateTime date,
      String playerUid,
      String displayName,
      TimeOfDay? startTime,
      TimeOfDay? endTime,
      bool recurring,
      List<bool> recurringDays,
      bool allDay) async {
    final event = {
      'player': playerUid,
      'displayName': displayName,
      'startTime': allDay ? '00:00' : startTime?.format(context) ?? '00:00',
      'endTime': allDay ? '23:59' : endTime?.format(context) ?? '23:59',
      'date': date.toIso8601String().split('T')[0],
      'votes': 0,
      'recurring': recurring,
      'recurringDays': recurring ? recurringDays : [],
      'allDay': allDay,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance.collection('schedules').add(event);
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

  Future<void> _clearAllAvailabilities() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please sign in to clear your availability.')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Your Availability'),
        content: const Text(
            'This will remove all your scheduled availability. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final playerUid = currentUser.uid;
      print('Clearing for UID: $playerUid'); // Fixed log
      final snapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .where('player', isEqualTo: playerUid)
          .get();

      print('Found ${snapshot.docs.length} schedules to delete');
      for (var doc in snapshot.docs) {
        print(
            'Deleting schedule ${doc.id} with player: ${doc.data()['player']}');
        await doc.reference.delete();
      }

      await _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All your availability cleared!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleNotification(
      TimeOfDay startTime, TimeOfDay endTime) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'match_channel',
        'Match Notifications',
        importance: Importance.high,
        priority: Priority.high,
      );
      const platformDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        DateTime.now().hashCode,
        'Availability Set',
        'You’re available from ${startTime.format(context)} to ${endTime.format(context)}',
        tz.TZDateTime.from(_selectedDay, _userTimeZone)
            .add(const Duration(minutes: 5)),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }

  Future<void> _sendInvites(String sender, String recipient, bool allDay,
      TimeOfDay startTime, TimeOfDay endTime) async {
    try {
      final message = allDay
          ? '$sender invited you to be available all day on ${DateFormat.yMMMd().format(_selectedDay)}'
          : '$sender invited you to be available from ${startTime.format(context)} to ${endTime.format(context)} on ${DateFormat.yMMMd().format(_selectedDay)}';
      await FirebaseFirestore.instance.collection('invites').add({
        'sender': sender,
        'recipient': recipient,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Invite error: $e');
    }
  }

  String _getAvailabilitySummary() {
    final events = _events[_selectedDay] ?? [];
    if (events.isEmpty) return 'No one has set availability yet.';
    final timeSlots = events
        .map((e) =>
            e['allDay'] ? 'All Day' : '${e['startTime']} - ${e['endTime']}')
        .toSet();
    return 'Time slots: ${timeSlots.join(', ')}';
  }

  List<Map<String, dynamic>> _getTimeSlotSummary() {
    final events = _events[_selectedDay] ?? [];
    final Map<String, List<String>> slotMap = {};
    for (var event in events) {
      final slot = event['allDay']
          ? 'All Day'
          : '${event['startTime']} - ${event['endTime']}';
      slotMap.update(slot, (list) => [...list, event['displayName']],
          ifAbsent: () => [event['displayName']]);
    }
    return slotMap.entries
        .map((e) => {'time': e.key, 'players': e.value})
        .toList()
      ..sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = _getTimeSlotSummary();

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
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                  headerStyle: HeaderStyle(
                    leftChevronIcon: Image.asset(
                      'assets/images/prev_month.png',
                      width: 24,
                      height: 24,
                      color: Colors.blue,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                    rightChevronIcon: Image.asset(
                      'assets/images/next_month.png',
                      width: 24,
                      height: 24,
                      color: Colors.blue,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                    titleCentered: true,
                    formatButtonVisible: true,
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                        color: Color.fromRGBO(0, 255, 255, 0.5),
                        shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(
                        color: Colors.blueAccent, shape: BoxShape.circle),
                    markerDecoration: const BoxDecoration(
                        color: Colors.redAccent, shape: BoxShape.circle),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Who’s Available Today',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (timeSlots.isEmpty)
                        const Text('No availability set yet.')
                      else
                        ...timeSlots.map((slot) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Text(slot['time'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(
                                          '${slot['players'].length} player${slot['players'].length > 1 ? 's' : ''}')),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Summary: ${_getAvailabilitySummary()}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_events[_selectedDay]?.isNotEmpty ?? false)
                ..._events[_selectedDay]!.map((event) => Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(event['displayName'][0],
                              style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text('${event['displayName']}'),
                        subtitle: Text(event['allDay']
                            ? 'All Day'
                            : '${event['startTime']} - ${event['endTime']} | Votes: ${event['votes']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _voteForEvent(event),
                              child: Image.asset(
                                'assets/images/thumbs_up.png',
                                width: 24,
                                height: 24,
                                color: Colors.blue,
                                colorBlendMode: BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (FirebaseAuth.instance.currentUser?.uid ==
                                event['player'])
                              GestureDetector(
                                onTap: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                          'Remove This Availability'),
                                      content: const Text(
                                          'Are you sure you want to remove this time slot?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await FirebaseFirestore.instance
                                        .collection('schedules')
                                        .doc(event['id'])
                                        .delete();
                                    await _loadEvents();
                                  }
                                },
                                child: Image.asset(
                                  'assets/images/clear_icon.png',
                                  width: 24,
                                  height: 24,
                                  color: Colors.blue,
                                  colorBlendMode: BlendMode.srcIn,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ))
              else
                const Center(child: Text('No availability set for this day')),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _isLoading ? null : _scheduleAvailabilityDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade700, Colors.green.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(0, 255, 0, 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Schedule My Availability',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _isLoading ? null : _clearAllAvailabilities,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(255, 0, 0, 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Clear All My Availability',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
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
