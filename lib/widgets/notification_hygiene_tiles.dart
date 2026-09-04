import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/notification_hygiene.dart';

/// Per-squad mute on chat-info. Live path writes [NotificationHygieneStore].
class MuteThisSquadTile extends StatelessWidget {
  const MuteThisSquadTile({
    super.key,
    required this.muted,
    required this.onChanged,
    this.neonColor = Colors.white,
  });

  final bool muted;
  final ValueChanged<bool> onChanged;
  final Color neonColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const Key('mute-this-squad'),
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                muted ? Icons.notifications_off : Icons.notifications,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Mute this squad',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              CupertinoSwitch(
                key: const Key('mute-this-squad-switch'),
                value: muted,
                onChanged: onChanged,
                activeTrackColor: neonColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Global quiet hours on Settings. Live path writes [NotificationHygieneStore].
class QuietHoursSettings extends StatelessWidget {
  const QuietHoursSettings({
    super.key,
    required this.enabled,
    required this.startMinutes,
    required this.endMinutes,
    required this.onEnabledChanged,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final bool enabled;
  final int startMinutes;
  final int endMinutes;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;

  @override
  Widget build(BuildContext context) {
    final window =
        '${NotificationHygiene.formatMinutes(startMinutes)} – ${NotificationHygiene.formatMinutes(endMinutes)}';
    return Column(
      key: const Key('quiet-hours-settings'),
      children: [
        SwitchListTile(
          key: const Key('quiet-hours-toggle'),
          secondary: Icon(
            Icons.bedtime,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text('Quiet Hours', style: GoogleFonts.robotoMono()),
          subtitle: Text(
            enabled
                ? 'No sends $window'
                : 'Pause notification sends during this window',
            style: GoogleFonts.robotoMono(fontSize: 12),
          ),
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        if (enabled) ...[
          ListTile(
            key: const Key('quiet-hours-start'),
            leading: Icon(
              Icons.schedule,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text('Starts', style: GoogleFonts.robotoMono()),
            trailing: Text(
              NotificationHygiene.formatMinutes(startMinutes),
              style: GoogleFonts.robotoMono(),
            ),
            onTap: () => _pick(context, startMinutes, onStartChanged),
          ),
          ListTile(
            key: const Key('quiet-hours-end'),
            leading: Icon(
              Icons.schedule,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text('Ends', style: GoogleFonts.robotoMono()),
            trailing: Text(
              NotificationHygiene.formatMinutes(endMinutes),
              style: GoogleFonts.robotoMono(),
            ),
            onTap: () => _pick(context, endMinutes, onEndChanged),
          ),
        ],
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    int currentMinutes,
    ValueChanged<int> onChanged,
  ) async {
    final clamped = ((currentMinutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60),
    );
    if (picked == null) return;
    onChanged(picked.hour * 60 + picked.minute);
  }
}
