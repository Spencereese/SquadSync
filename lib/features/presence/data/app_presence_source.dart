import 'package:squadsync/features/presence/domain/app_presence.dart';

/// In-memory presence for one squad. No table. Closing the stream untracks.
abstract class AppPresenceSource {
  Stream<AppPresenceBoard> watch({
    required String squadId,
    required String userId,
  });
}
