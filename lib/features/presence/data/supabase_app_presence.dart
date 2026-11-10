import 'dart:async';

import 'package:squadsync/features/presence/data/app_presence_source.dart';
import 'package:squadsync/features/presence/domain/app_presence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Realtime Presence on `sq8-presence-<squad>`. Nothing is stored.
class SupabaseAppPresence implements AppPresenceSource {
  SupabaseAppPresence(this._client);

  final SupabaseClient _client;

  @override
  Stream<AppPresenceBoard> watch({
    required String squadId,
    required String userId,
  }) {
    final channel = _client.channel(appPresenceTopic(squadId));
    final controller = StreamController<AppPresenceBoard>.broadcast();

    void emitHere() {
      if (controller.isClosed) return;
      final payloads = <Map<String, dynamic>>[
        for (final row in channel.presenceState())
          for (final presence in row.presences) presence.payload,
      ];
      controller.add(
        AppPresenceBoard(available: true, here: presenceUserIds(payloads)),
      );
    }

    void emitDown() {
      if (!controller.isClosed) {
        controller.add(const AppPresenceBoard.unavailable());
      }
    }

    channel.onPresenceSync((_) => emitHere());
    channel.subscribe((status, _) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await channel.track({'user_id': userId});
          emitHere();
        } on Object {
          emitDown();
        }
        return;
      }
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut ||
          status == RealtimeSubscribeStatus.closed) {
        emitDown();
      }
    });

    controller.onCancel = () async {
      try {
        await channel.untrack();
      } on Object {
        // Already gone. The dot must not throw.
      }
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }
}
