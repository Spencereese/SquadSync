import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/notifiers/lobby_notifier.dart' as ln;
import 'fill_pin_thread_header.dart';

const kFillPinGroupRowBadgeKey = Key('fill-pin-group-row-badge');
const kFillPinGroupRowBadgeSeatKey = Key('fill-pin-group-row-badge-seats');

/// Compact live n/max on a My Groups row when THIS group has an active pin.
/// Shrinks to nothing when there is no this-group pin.
class FillPinGroupRowBadge extends ConsumerWidget {
  const FillPinGroupRowBadge({super.key, required this.chatGroupId});

  final String chatGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ln.lobbyNotifierProvider).valueOrNull;
    final snapshot =
        resolveFillPinForThread(state: state, chatGroupId: chatGroupId);
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
    return Padding(
      key: kFillPinGroupRowBadgeKey,
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        '${snapshot.gameName} ${snapshot.seatLabel}',
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
