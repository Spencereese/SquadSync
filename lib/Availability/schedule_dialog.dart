import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleDialog extends StatefulWidget {
  final DateTime selectedDay;

  const ScheduleDialog({super.key, required this.selectedDay});

  @override
  _ScheduleDialogState createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  late DateTime startTime;
  late DateTime endTime;
  bool isAllDay = false;
  List<bool> recurringDays = List.filled(7, false); // Sun-Sat
  String inviteOption = 'None'; // Default to "None"
  String alertOption = 'None';
  bool showStartPicker = false;
  bool showEndPicker = false;

  final List<String> alertOptions = [
    'None',
    '5 minutes before',
    '10 minutes before',
    '15 minutes before',
    '30 minutes before',
    '1 hour before',
    '2 hours before',
    '1 day before',
    '2 days before',
    '1 week before'
  ];
  late Future<List<String>> squadMembersFuture;

  // Hardcoded list from SquadQueueLogic
  final List<String> defaultSquadMembers = [
    "Alex",
    "Spencer",
    "Landon",
    "Drew",
    "John",
    "Dalton",
    "Levi",
    "Daniel"
  ];

  @override
  void initState() {
    super.initState();
    startTime = _roundToNearestFive(widget.selectedDay);
    endTime = startTime.add(const Duration(hours: 1));
    squadMembersFuture = _fetchSquadMembers();
  }

  DateTime _roundToNearestFive(DateTime time) {
    final minutes = time.minute;
    final roundedMinutes = (minutes / 5).round() * 5;
    return DateTime(time.year, time.month, time.day, time.hour, roundedMinutes);
  }

  Future<List<String>> _fetchSquadMembers() async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('squad').doc('state');
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        // If the document doesn't exist, create it with the default members
        await docRef.set({
          'members': defaultSquadMembers,
          'squadSpots': List.filled(4, null),
          'spotTimers': List.filled(4, null),
        }, SetOptions(merge: true));
        debugPrint(
            'Created squad/state with default members: $defaultSquadMembers');
        return defaultSquadMembers;
      }

      final data = snapshot.data()!;
      if (!data.containsKey('members') ||
          (data['members'] as List<dynamic>).isEmpty) {
        // If members field is missing or empty, initialize it
        await docRef.update({
          'members': defaultSquadMembers,
        });
        debugPrint('Initialized members field with: $defaultSquadMembers');
        return defaultSquadMembers;
      }

      final members = List<String>.from(data['members'] as List<dynamic>);
      debugPrint('Fetched members: $members');
      return members;
    } catch (e) {
      debugPrint('Error fetching squad members: $e');
      return defaultSquadMembers;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.blueGrey[900],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Call To Arms',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent[100],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildSectionCard(
                  title: 'Time',
                  children: [
                    _buildSwitchRow(
                      label: 'All Day',
                      value: isAllDay,
                      onChanged: (value) => setState(() => isAllDay = value),
                    ),
                    if (!isAllDay) ...[
                      const SizedBox(height: 16),
                      _buildTimePickerRow(
                        label: 'Start',
                        time: startTime,
                        showPicker: showStartPicker,
                        onTap: () => setState(() {
                          showStartPicker = !showStartPicker;
                          showEndPicker = false;
                        }),
                        onTimeChanged: (duration) => setState(() {
                          startTime = DateTime(
                            widget.selectedDay.year,
                            widget.selectedDay.month,
                            widget.selectedDay.day,
                            duration.inHours,
                            duration.inMinutes % 60,
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      _buildTimePickerRow(
                        label: 'End',
                        time: endTime,
                        showPicker: showEndPicker,
                        onTap: () => setState(() {
                          showEndPicker = !showEndPicker;
                          showStartPicker = false;
                        }),
                        onTimeChanged: (duration) => setState(() {
                          endTime = DateTime(
                            widget.selectedDay.year,
                            widget.selectedDay.month,
                            widget.selectedDay.day,
                            duration.inHours,
                            duration.inMinutes % 60,
                          );
                        }),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'Repeat',
                  children: [
                    _buildTapRow(
                      label: 'Repeat',
                      value: recurringDays.any((day) => day)
                          ? recurringDays
                              .asMap()
                              .entries
                              .where((e) => e.value)
                              .map((e) =>
                                  ['S', 'M', 'T', 'W', 'T', 'F', 'S'][e.key])
                              .join(', ')
                          : 'Never',
                      onTap: () => _showRecurringDaysPicker(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'Invite',
                  children: [
                    _buildTapRow(
                      label: 'Invite',
                      value: inviteOption,
                      onTap: () => _showInvitePicker(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'Alert',
                  children: [
                    _buildTapRow(
                      label: 'Alert',
                      value: alertOption,
                      onTap: () => _showAlertPicker(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 4,
      color: Colors.blueGrey[800],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent[100],
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 16, color: Colors.blueGrey[300])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.cyanAccent[100],
          inactiveTrackColor: Colors.blueGrey[600],
        ),
      ],
    );
  }

  Widget _buildTapRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 16, color: Colors.blueGrey[300])),
          Row(
            children: [
              Text(value,
                  style:
                      TextStyle(fontSize: 16, color: Colors.cyanAccent[100])),
              const SizedBox(width: 8),
              Icon(Icons.arrow_drop_down,
                  color: Colors.cyanAccent[100], size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerRow({
    required String label,
    required DateTime time,
    required bool showPicker,
    required VoidCallback onTap,
    required ValueChanged<Duration> onTimeChanged,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 16, color: Colors.blueGrey[300])),
              Text(
                DateFormat('h:mm a').format(time),
                style: TextStyle(fontSize: 16, color: Colors.cyanAccent[100]),
              ),
            ],
          ),
        ),
        if (showPicker)
          SizedBox(
            height: 150,
            child: CupertinoTimerPicker(
              mode: CupertinoTimerPickerMode.hm,
              initialTimerDuration:
                  Duration(hours: time.hour, minutes: time.minute),
              minuteInterval: 5,
              onTimerDurationChanged: onTimeChanged,
            ),
          ),
      ],
    );
  }

  void _showRecurringDaysPicker(BuildContext context) async {
    final List<String> daysOfWeek = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    final int selectedDayIndex = widget.selectedDay.weekday % 7; // 0=Sun, 6=Sat
    final List<String> orderedDays = [
      daysOfWeek[selectedDayIndex],
      ...daysOfWeek.sublist(selectedDayIndex + 1),
      ...daysOfWeek.sublist(0, selectedDayIndex),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.blueGrey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Days to Repeat',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyanAccent[100]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(7, (index) {
                  final dayIndex = (selectedDayIndex + index) % 7;
                  return GestureDetector(
                    onTap: () => setState(() =>
                        recurringDays[dayIndex] = !recurringDays[dayIndex]),
                    child: Container(
                      decoration: BoxDecoration(
                        color: recurringDays[dayIndex]
                            ? Colors.cyanAccent[100]
                            : Colors.blueGrey[700],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          orderedDays[index],
                          style: TextStyle(
                            color: recurringDays[dayIndex]
                                ? Colors.blueGrey[900]
                                : Colors.cyanAccent[100],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInvitePicker(BuildContext context) async {
    final members = await squadMembersFuture;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.blueGrey[900],
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Invite Members',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyanAccent[100]),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text('Invite All Members',
                  style: TextStyle(color: Colors.blueGrey[300])),
              value: inviteOption == 'All Members',
              onChanged: (value) {
                setState(() => inviteOption = value ? 'All Members' : 'None');
              },
              activeColor: Colors.cyanAccent[100],
              inactiveTrackColor: Colors.blueGrey[600],
            ),
            if (inviteOption != 'All Members')
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  onSelectedItemChanged: (index) {
                    setState(() => inviteOption = members[index]);
                  },
                  children: members
                      .map((member) => Center(
                            child: Text(member,
                                style:
                                    TextStyle(color: Colors.cyanAccent[100])),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAlertPicker(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.blueGrey[900],
      builder: (context) => Container(
        height: 250,
        child: CupertinoPicker(
          itemExtent: 40,
          onSelectedItemChanged: (index) =>
              setState(() => alertOption = alertOptions[index]),
          children: alertOptions
              .map((option) => Center(
                  child: Text(option,
                      style: TextStyle(color: Colors.cyanAccent[100]))))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: Colors.red[400], fontSize: 16)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'startTime': startTime,
            'endTime': endTime,
            'isAllDay': isAllDay,
            'repeatOption':
                recurringDays.any((day) => day) ? 'Weekly' : 'Never',
            'recurringDays': recurringDays,
            'invitees': inviteOption,
            'alertOption': alertOption,
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Set',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }
}
