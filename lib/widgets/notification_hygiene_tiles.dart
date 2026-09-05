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

  static const titleLabel = 'Mute this squad';
  static const emptyLabel = 'Notifications from this squad stay on';
  static const mutedLabel = 'No pings from this squad until you unmute';

  final bool muted;
  final ValueChanged<bool> onChanged;
  final Color neonColor;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleLabel,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      muted ? mutedLabel : emptyLabel,
                      key: muted
                          ? const Key('mute-this-squad-on')
                          : const Key('mute-this-squad-empty'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
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

/// Chat-info shortcut into Settings quiet hours. Same pipeline, no new store.
class QuietHoursSettingsEntry extends StatelessWidget {
  const QuietHoursSettingsEntry({
    super.key,
    required this.onOpen,
    this.neonColor = Colors.white,
  });

  static const titleLabel = 'Quiet hours';
  static const subtitleLabel = 'Pause all notification sends in Settings';

  final VoidCallback onOpen;
  final Color neonColor;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ClipRRect(
      key: const Key('quiet-hours-settings-entry'),
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
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
                  const Icon(Icons.bedtime, color: Colors.white, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleLabel,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: neonColor.withOpacity(0.8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings intro so quiet hours + mute are not buried under other toggles.
class NotificationHygieneSettingsHeader extends StatelessWidget {
  const NotificationHygieneSettingsHeader({super.key});

  static const titleLabel = 'Quiet hours & mute';
  static const subtitleLabel =
      'Pause all notification sends at night, or mute one squad from its info.';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const Key('notification-hygiene-entry'),
      leading: Icon(
        Icons.notifications_paused,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(titleLabel, style: GoogleFonts.robotoMono()),
      subtitle: Text(
        subtitleLabel,
        style: GoogleFonts.robotoMono(fontSize: 12),
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

  static const titleLabel = 'Quiet hours';

  final bool enabled;
  final int startMinutes;
  final int endMinutes;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;

  String get windowLabel =>
      '${NotificationHygiene.formatMinutes(startMinutes)} – ${NotificationHygiene.formatMinutes(endMinutes)}';

  String get emptyLabel =>
      'Off — pause all notification sends $windowLabel';

  String get onLabel => 'Pausing all notification sends $windowLabel';

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('quiet-hours-settings'),
      children: [
        SwitchListTile(
          key: const Key('quiet-hours-toggle'),
          secondary: Icon(
            Icons.bedtime,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(titleLabel, style: GoogleFonts.robotoMono()),
          subtitle: Text(
            enabled ? onLabel : emptyLabel,
            key: enabled
                ? const Key('quiet-hours-on')
                : const Key('quiet-hours-empty'),
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

/// Settings empty / count for muted squads. Mute still happens on squad info.
class MutedSquadsSettingsTile extends StatelessWidget {
  const MutedSquadsSettingsTile({
    super.key,
    required this.mutedCount,
  });

  static const titleLabel = 'Muted squads';
  static const emptyLabel =
      'No muted squads. Open a squad\'s info to mute notifications from that squad.';
  static const countHint = 'Unmute from that squad\'s info.';

  final int mutedCount;

  String get countLabel {
    if (mutedCount == 1) return '1 muted squad. $countHint';
    return '$mutedCount muted squads. $countHint';
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = mutedCount <= 0;
    return ListTile(
      key: isEmpty
          ? const Key('muted-squads-empty')
          : const Key('muted-squads-count'),
      leading: Icon(
        isEmpty ? Icons.notifications_none : Icons.notifications_off,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(titleLabel, style: GoogleFonts.robotoMono()),
      subtitle: Text(
        isEmpty ? emptyLabel : countLabel,
        style: GoogleFonts.robotoMono(fontSize: 12),
      ),
    );
  }
}
