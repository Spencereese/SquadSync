import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import '../../presentation/notifiers/notification_notifier.dart';

/// In-app badge widget for chat, lobby, and invite indicators
/// Shows unread counts with Material 3 theming
class NotificationBadge extends ConsumerWidget {
  final Widget child;
  final String badgeType; // 'chat', 'lobby', 'invites'
  final bool showZero;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.badgeType,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeState = ref.watch(notificationNotifierProvider);

    return badgeState.when(
      data: (state) {
        final count = _getBadgeCount(state);

        if (count == 0 && !showZero) {
          return child;
        }

        return badges.Badge(
          badgeContent: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          badgeStyle: badges.BadgeStyle(
            badgeColor: _getBadgeColor(context),
            padding: const EdgeInsets.all(4),
            elevation: 2,
          ),
          position: badges.BadgePosition.topEnd(top: -4, end: -4),
          showBadge: count > 0 || showZero,
          child: child,
        );
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }

  int _getBadgeCount(badgeState) {
    switch (badgeType) {
      case 'chat':
        return badgeState.chatUnreadCount;
      case 'lobby':
        return badgeState.lobbyUpdatesCount;
      case 'invites':
        return badgeState.invitesCount;
      default:
        return 0;
    }
  }

  Color _getBadgeColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (badgeType) {
      case 'chat':
        return theme.colorScheme.primary;
      case 'lobby':
        return theme.colorScheme.tertiary;
      case 'invites':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.primary;
    }
  }
}

/// Momentum indicator - animated pulse for active lobbies
class MomentumBadge extends ConsumerWidget {
  final Widget child;

  const MomentumBadge({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeState = ref.watch(notificationNotifierProvider);

    return badgeState.when(
      data: (state) {
        if (!state.hasMomentum) {
          return child;
        }

        return Stack(
          children: [
            child,
            Positioned(
              top: -2,
              right: -2,
              child: _buildPulsingDot(context),
            ),
          ],
        );
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }

  Widget _buildPulsingDot(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Container(
          width: 12 * value,
          height: 12 * value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.error.withOpacity(value),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                blurRadius: 8 * value,
                spreadRadius: 2 * value,
              ),
            ],
          ),
        );
      },
      onEnd: () {
        // Loop animation by rebuilding
      },
    );
  }
}

/// Badge clearing button - tap to clear specific badge type
class BadgeClearButton extends ConsumerWidget {
  final String badgeType;
  final Widget? child;

  const BadgeClearButton({
    super.key,
    required this.badgeType,
    this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(notificationNotifierProvider.notifier).clearBadge(badgeType);
      },
      child: child ?? const SizedBox.shrink(),
    );
  }
}
