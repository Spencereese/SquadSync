import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/notifiers/lobby_notifier.dart' as ln;
import '../services/coming_hold_machine.dart';
import 'fill_pin_header_actions.dart';
import 'fill_pin_thread_header.dart';

const kFillPinGroupRowBadgeKey = Key('fill-pin-group-row-badge');
const kFillPinGroupRowBadgeSeatKey = Key('fill-pin-group-row-badge-seats');

/// Compact live n/max on a My Groups row when THIS group has an active pin.
/// Shrinks to nothing when there is no this-group pin.
class FillPinGroupRowBadge extends ConsumerStatefulWidget {
  const FillPinGroupRowBadge({super.key, required this.chatGroupId});

  final String chatGroupId;

  @override
  ConsumerState<FillPinGroupRowBadge> createState() =>
      _FillPinGroupRowBadgeState();
}

class _FillPinGroupRowBadgeState extends ConsumerState<FillPinGroupRowBadge> {
  ComingHoldState? _hold;

  @override
  void initState() {
    super.initState();
    listenFillPinHeaderHold(_onHold);
  }

  @override
  void dispose() {
    unlistenFillPinHeaderHold(_onHold);
    super.dispose();
  }

  void _onHold(ComingHoldState hold) {
    if (!mounted) return;
    setState(() => _hold = hold);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ln.lobbyNotifierProvider).valueOrNull;
    final snapshot = resolveFillPinForThread(
      state: state,
      chatGroupId: widget.chatGroupId,
      hold: _hold,
    );
    if (snapshot == null) return const SizedBox.shrink();
    return FillPinGroupRowBadgeView(snapshot: snapshot);
  }
}

/// Presentational row badge. No list-theme rewrite.
class FillPinGroupRowBadgeView extends StatelessWidget {
  const FillPinGroupRowBadgeView({super.key, required this.snapshot});

  final FillPinSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final chrome = snapshot.comingCountdown?.trim() ?? '';
    final label = chrome.isEmpty
        ? '${snapshot.gameName} ${snapshot.seatLabel}'
        : '${snapshot.gameName} ${snapshot.seatLabel} $chrome';
    return Padding(
      key: kFillPinGroupRowBadgeKey,
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        label,
        key: kFillPinGroupRowBadgeSeatKey,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
