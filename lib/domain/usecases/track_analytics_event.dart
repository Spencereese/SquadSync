import 'package:squad_sync/domain/repositories/system_repository.dart';

class TrackAnalyticsEvent {
  final SystemRepository _repository;

  TrackAnalyticsEvent(this._repository);

  Future<void> call(String event, Map<String, dynamic> data) =>
      _repository.trackAnalyticsEvent(event, data);
}