import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
import 'package:squadsync/features/chat/ui/squad_chat_controller.dart';
import 'package:squadsync/features/chat/ui/squad_chat_screen.dart';
import 'package:squadsync/features/push/data/push_notifications.dart';
import 'package:squadsync/features/push/domain/squad_push.dart';

class PushInboxState {
  const PushInboxState({
    this.notificationsOn = false,
    this.setupMissing = false,
    this.route,
    this.messageId,
  });

  final bool notificationsOn;
  final bool setupMissing;
  final SquadPushRoute? route;
  final String? messageId;

  PushInboxState copyWith({
    bool? notificationsOn,
    bool? setupMissing,
    SquadPushRoute? route,
    String? messageId,
    bool clearRoute = false,
  }) {
    return PushInboxState(
      notificationsOn: notificationsOn ?? this.notificationsOn,
      setupMissing: setupMissing ?? this.setupMissing,
      route: clearRoute ? null : (route ?? this.route),
      messageId: clearRoute ? null : (messageId ?? this.messageId),
    );
  }
}

class PushInbox extends Notifier<PushInboxState> {
  SquadPush? _waiting;

  @override
  PushInboxState build() => const PushInboxState();

  void noteAvailability(PushAvailability availability) {
    state = state.copyWith(
      notificationsOn: availability.on,
      setupMissing: availability.setupMissing,
    );
  }

  void ingest(SquadPush push) {
    final decision = routeSquadPush(
      signedIn: _signedIn,
      openSquadId: _squadId,
      push: push,
    );
    if (decision == SquadPushRoute.wait) {
      _waiting = push;
      state = state.copyWith(route: decision, messageId: push.messageId);
      return;
    }
    _waiting = null;
    state = state.copyWith(route: decision, messageId: push.messageId);
  }

  void flush() {
    final waiting = _waiting;
    if (waiting == null) return;
    ingest(waiting);
  }

  bool get _signedIn {
    final link = ref.read(appLinkProvider);
    if (link == AppLink.demo) return true;
    return ref.read(authRepositoryProvider).currentUser != null;
  }

  String? get _squadId => ref.read(squadChatControllerProvider).squad?.id;
}

final pushInboxProvider = NotifierProvider<PushInbox, PushInboxState>(
  PushInbox.new,
);

/// Signed-in person for push routing. Demo does not use this stream.
final pushSessionProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchUser();
});

/// Honest push state. Off until a real token exists. A tap never opens
/// a squad the person is not in.
class NotificationsStatus extends ConsumerWidget {
  const NotificationsStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(pushInboxProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!inbox.notificationsOn && inbox.setupMissing)
          const Text(
            'Notifications off: not set up yet',
            key: Key('notifications-not-set-up'),
          ),
        if (!inbox.notificationsOn && !inbox.setupMissing)
          const Text('Notifications off', key: Key('notifications-off')),
      ],
    );
  }
}

/// Listens for a launch or a tap for the whole process. Draws nothing.
class PushListener extends ConsumerStatefulWidget {
  const PushListener({super.key});

  @override
  ConsumerState<PushListener> createState() => _PushListenerState();
}

class _PushListenerState extends ConsumerState<PushListener> {
  StreamSubscription<SquadPush>? _taps;
  StreamSubscription<PushAvailability>? _tokens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  @override
  void dispose() {
    final taps = _taps;
    final tokens = _tokens;
    _taps = null;
    _tokens = null;
    if (taps != null) unawaited(taps.cancel());
    if (tokens != null) unawaited(tokens.cancel());
    super.dispose();
  }

  bool _shouldRegister() {
    if (ref.read(appLinkProvider) == AppLink.demo) return true;
    return ref.read(authRepositoryProvider).currentUser != null;
  }

  Future<void> _register(PushAvailability availability) async {
    if (!availability.on || !_shouldRegister()) return;
    await ref
        .read(pushTokenRepositoryProvider)
        .register(token: availability.token!, platform: availability.platform!);
  }

  Future<void> _start() async {
    if (!mounted) return;
    final pushes = ref.read(pushNotificationsProvider);
    final availability = await pushes.availability();
    if (!mounted) return;
    ref.read(pushInboxProvider.notifier).noteAvailability(availability);
    await _register(availability);
    final launch = pushes.consumeLaunch();
    if (launch != null) {
      ref.read(pushInboxProvider.notifier).ingest(launch);
    }
    _taps = pushes.taps.listen((push) {
      ref.read(pushInboxProvider.notifier).ingest(push);
    });
    _tokens = pushes.tokenChanges.listen((next) {
      ref.read(pushInboxProvider.notifier).noteAvailability(next);
      unawaited(_register(next));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pushInboxProvider, (previous, next) {
      if (next.route == SquadPushRoute.openChat &&
          previous?.route != SquadPushRoute.openChat) {
        ref.read(squadHomeViewProvider.notifier).openThread();
      }
    });
    ref.listen(squadChatControllerProvider, (previous, next) {
      if (previous?.squad?.id == next.squad?.id) return;
      ref.read(pushInboxProvider.notifier).flush();
    });
    ref.listen(pushSessionProvider, (previous, next) {
      ref.read(pushInboxProvider.notifier).flush();
      final user = next.asData?.value;
      if (user == null) return;
      unawaited(_registerFromSession());
    });
    final inbox = ref.watch(pushInboxProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inbox.route == SquadPushRoute.openChat)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Opened the squad chat.', key: Key('push-opened-chat')),
          ),
        if (inbox.route == SquadPushRoute.wrongSquad)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'That notification is for a squad you are not in.',
              key: Key('push-wrong-squad'),
            ),
          ),
      ],
    );
  }

  Future<void> _registerFromSession() async {
    final availability = await ref
        .read(pushNotificationsProvider)
        .availability();
    if (!mounted) return;
    await _register(availability);
  }
}
