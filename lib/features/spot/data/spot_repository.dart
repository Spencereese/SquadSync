import 'package:squadsync/features/spot/domain/spot_call.dart';

/// Server-owned spot calls. A missing table is [SpotNotEnabled].
abstract class SpotRepository {
  Future<SpotCall?> load({required String squadId});

  Future<SpotCall> callSpot({
    required String squadId,
    required String game,
    required DateTime startsAt,
  });

  Future<void> rsvp({required String callId, required SpotAnswer answer});

  Future<void> lock({required String callId});
}

class SpotNotEnabled implements Exception {
  const SpotNotEnabled();
}
