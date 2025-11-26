import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:squad_sync/Availability/schedule_dialog.dart';
import 'package:squad_sync/presentation/notifiers/squad_notifier.dart' as sn;
import 'package:squad_sync/managers/stubs.dart';
import 'package:squad_sync/domain/entities/squad_state.dart';

class AvailabilityTab extends ConsumerStatefulWidget {
  const AvailabilityTab({super.key});

  @override
  ConsumerState<AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends ConsumerState<AvailabilityTab> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
  }

  Future<void> _scheduleAvailabilityDialog(
      BuildContext context, DateTime selectedDay) async {
    final squadState = ref.read(sn.squadNotifierProvider).value!;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ScheduleDialog(selectedDay: selectedDay),
    );

    if (result == null) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('You must be signed in.');
      final playerUid = currentUser.uid;
      final displayName = currentUser.displayName ?? 'Unknown';

      final startTime = result['startTime'] as DateTime;
      final endTime = result['endTime'] as DateTime;
      final scheduledDay = result['scheduledDay'] as DateTime;
      final isAllDay = result['isAllDay'] as bool;
      final repeatOption = result['repeatOption'] as String;
      final recurringDays = result['recurringDays'] as List<bool>;
      final invitees = result['invitees'] as String;
      final alertOption = result['alertOption'] as String;

      final startTimeOfDay = TimeOfDay.fromDateTime(startTime);
      final endTimeOfDay = TimeOfDay.fromDateTime(endTime);
      final isRecurring = repeatOption != 'Never';

      debugPrint('Scheduling for $scheduledDay, isRecurring: $isRecurring');

      if (isRecurring) {
        final startDate = scheduledDay;
        for (int i = 0; i < 30; i++) {
          final date = startDate.add(Duration(days: i));
          if (repeatOption == 'Daily' ||
              (repeatOption == 'Weekly' && recurringDays[date.weekday % 7]) ||
              (repeatOption == 'Monthly' && date.day == scheduledDay.day)) {
            await _addEvent(
                context,
                date,
                playerUid,
                displayName,
                isAllDay ? null : startTimeOfDay,
                isAllDay ? null : endTimeOfDay,
                isRecurring,
                recurringDays,
                isAllDay,
                alertOption,
                squadState);
          }
        }
      } else {
        await _addEvent(
            context,
            scheduledDay,
            playerUid,
            displayName,
            isAllDay ? null : startTimeOfDay,
            isAllDay ? null : endTimeOfDay,
            false,
            [],
            isAllDay,
            alertOption,
            squadState);
      }

      if (!isAllDay && alertOption != 'None') {
        await _scheduleNotification(
            context, scheduledDay, startTimeOfDay, endTimeOfDay, alertOption);
      }
      if (invitees != 'None') {
        await _sendInvites(
            context,
            displayName,
            invitees == 'All Members' ? 'Squad' : invitees,
            isAllDay,
            startTimeOfDay,
            endTimeOfDay,
            scheduledDay);
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Availability scheduled!')),
      );
    } catch (e) {
      debugPrint('Error in _scheduleAvailabilityDialog: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to schedule: $e')),
      );
    }
  }

  Future<void> _addEvent(
      BuildContext context,
      DateTime date,
      String playerUid,
      String displayName,
      TimeOfDay? startTime,
      TimeOfDay? endTime,
      bool isRecurring,
      List<bool> recurringDays,
      bool isAllDay,
      String alertOption,
      SquadState squadState) async {
    String formatTimeOfDay(TimeOfDay? time) {
      if (time == null) return '00:00';
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    final event = {
      'player': playerUid,
      'displayName': displayName,
      'startTime': isAllDay ? '00:00' : formatTimeOfDay(startTime),
      'endTime': isAllDay ? '23:59' : formatTimeOfDay(endTime),
      'date': date.toIso8601String().split('T')[0],
      'votes': 0,
      'recurring': isRecurring,
      'recurringDays': isRecurring ? recurringDays : [],
      'allDay': isAllDay,
      'alert': alertOption,
      'createdAt': FieldValue.serverTimestamp(),
    };

    debugPrint('Adding event to Firestore schedules collection: $event');

    final firestoreManager =
        p.Provider.of<FirestoreManager>(context, listen: false);
    await firestoreManager.addScheduleEvent(event);
  }

  Future<void> _voteForEvent(BuildContext context, String eventId) async {
    final firestoreManager =
        p.Provider.of<FirestoreManager>(context, listen: false);
    await firestoreManager.voteForScheduleEvent(eventId);
  }

  Future<void> _clearAllAvailabilities(
      BuildContext context, SquadState squadState) async {
    final messenger = ScaffoldMessenger.of(context);
    final firestoreManager =
        p.Provider.of<FirestoreManager>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in to clear availability.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Availability'),
        content: const Text(
            'This will remove all your scheduled availability. Confirm?'),
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

    try {
      final playerUid = currentUser.uid;
      final docs = await firestoreManager.getUserScheduleEvents(playerUid);
      for (var doc in docs) {
        await firestoreManager.deleteScheduleEvent(doc['id']);
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('All availability cleared!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to clear: $e')),
      );
    }
  }

  Future<void> _scheduleNotification(BuildContext context, DateTime selectedDay,
      TimeOfDay startTime, TimeOfDay endTime, String alertOption) async {
    final notificationManager =
        p.Provider.of<NotificationManager>(context, listen: false);
    if (alertOption == 'None') return;

    final now = DateTime.now();
    final alertTime = DateTime(selectedDay.year, selectedDay.month,
        selectedDay.day, startTime.hour, startTime.minute);

    Duration offset;
    switch (alertOption) {
      case '5 minutes before':
        offset = const Duration(minutes: 5);
        break;
      case '10 minutes before':
        offset = const Duration(minutes: 10);
        break;
      case '15 minutes before':
        offset = const Duration(minutes: 15);
        break;
      case '30 minutes before':
        offset = const Duration(minutes: 30);
        break;
      case '1 hour before':
        offset = const Duration(hours: 1);
        break;
      case '2 hours before':
        offset = const Duration(hours: 2);
        break;
      case '1 day before':
        offset = const Duration(days: 1);
        break;
      case '2 days before':
        offset = const Duration(days: 2);
        break;
      case '1 week before':
        offset = const Duration(days: 7);
        break;
      default:
        return;
    }

    final scheduledTime = alertTime.subtract(offset);
    if (scheduledTime.isBefore(now)) {
      return; // Don't schedule past notifications
    }

    await notificationManager.scheduleNotification(
      title: 'Availability Reminder',
      body:
          'Your scheduled availability starts at ${startTime.format(context)}',
      scheduledTime: scheduledTime,
    );
  }

  Future<void> _sendInvites(
      BuildContext context,
      String sender,
      String recipient,
      bool allDay,
      TimeOfDay startTime,
      TimeOfDay endTime,
      DateTime selectedDay) async {
    final firestoreManager =
        p.Provider.of<FirestoreManager>(context, listen: false);
    try {
      final message = allDay
          ? '$sender invited you to be available all day on ${DateFormat.yMMMd().format(selectedDay)}'
          : '$sender invited you to be available from ${startTime.format(context)} to ${endTime.format(context)} on ${DateFormat.yMMMd().format(selectedDay)}';
      await firestoreManager.sendInvite({
        'sender': sender,
        'recipient': recipient,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Invite error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final squadStateAsync = ref.watch(sn.squadNotifierProvider);
    return squadStateAsync.when(
      data: (squadState) {
        final events = _mapScheduledTimes(squadState.scheduledTimes);
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              // No need to force updateFirestore here; schedules listener will refresh
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0)
                        .copyWith(top: 16.0 + kToolbarHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DEBUG: 9 AVAILABILITY',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        _buildCalendar(context, events),
                        const SizedBox(height: 16),
                        _buildDayBreakdown(context, events),
                        const SizedBox(height: 16),
                        _buildClearButton(context, squadState),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: const SizedBox(height: 80.0),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _scheduleAvailabilityDialog(context, _selectedDay),
            backgroundColor: Colors.green.shade600,
            tooltip: 'Schedule Availability',
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Map<DateTime, List<Map<String, dynamic>>> _mapScheduledTimes(
      List<Map<String, dynamic>> scheduledTimes) {
    final Map<DateTime, List<Map<String, dynamic>>> events = {};
    for (var event in scheduledTimes) {
      final dateString = event['date'];
      if (dateString == null) {
        debugPrint('Skipping event with null date: $event');
        continue; // Skip events with no date
      }
      try {
        final date = DateTime.parse(dateString as String);
        final eventDate = DateTime(date.year, date.month, date.day);
        events.update(
          eventDate,
          (list) => [...list, event],
          ifAbsent: () => [event],
        );
      } catch (e) {
        debugPrint(
            'Failed to parse date "$dateString" in event: $event, error: $e');
        continue; // Skip events with invalid dates
      }
    }
    return events;
  }

  Widget _buildCalendar(
      BuildContext context, Map<DateTime, List<Map<String, dynamic>>> events) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (newSelectedDay, newFocusedDay) {
          setState(() {
            _selectedDay = newSelectedDay;
            _focusedDay = newFocusedDay;
          });
        },
        eventLoader: (day) =>
            events[DateTime(day.year, day.month, day.day)] ?? [],
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.green.shade600,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
        ),
      ),
    );
  }

  Widget _buildDayBreakdown(
      BuildContext context, Map<DateTime, List<Map<String, dynamic>>> events) {
    final dayEvents = events[DateTime(
            _selectedDay.year, _selectedDay.month, _selectedDay.day)] ??
        [];

    if (dayEvents.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('No availability set for this day')),
        ),
      );
    }

    final Map<String, List<Map<String, dynamic>>> timeSlots = {};
    for (var event in dayEvents) {
      final slot = event['allDay']
          ? 'All Day'
          : '${event['startTime']} - ${event['endTime']}';
      timeSlots.update(slot, (list) => [...list, event],
          ifAbsent: () => [event]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Availability for ${DateFormat.yMMMd().format(_selectedDay)}',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: timeSlots.length,
          itemBuilder: (context, index) {
            final slot = timeSlots.keys.elementAt(index);
            final slotEvents = timeSlots[slot]!;
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            slot,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${slotEvents.length} player${slotEvents.length > 1 ? 's' : ''}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...slotEvents
                        .map((event) => _buildPlayerTile(context, event)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlayerTile(BuildContext context, Map<String, dynamic> event) {
    final messenger = ScaffoldMessenger.of(context);
    final isOwnEvent =
        FirebaseAuth.instance.currentUser?.uid == event['player'];
    final displayName = event['displayName'] as String? ?? 'Unknown';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green.shade400,
            child: Text(
              displayName.isNotEmpty ? displayName[0] : 'U',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.thumb_up, color: Colors.blue),
                onPressed: () => _voteForEvent(context, event['id']),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                '${event['votes']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (isOwnEvent) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirmed =
                        await _confirmDelete(context, displayName);
                    if (confirmed == true) {
                      final firestoreManager = p.Provider.of<FirestoreManager>(
                          context,
                          listen: false);
                      await firestoreManager.deleteScheduleEvent(event['id']);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Availability removed!')),
                      );
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClearButton(BuildContext context, SquadState squadState) {
    return OutlinedButton.icon(
      onPressed: () => _clearAllAvailabilities(context, squadState),
      icon: const Icon(Icons.clear_all, color: Colors.red),
      label: const Text('Clear My Availability'),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String displayName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $displayName\'s Availability'),
        content: const Text('Are you sure you want to remove this time slot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
