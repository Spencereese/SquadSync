import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/availability/data/availability_repository.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String checkInKindKey(CheckInKind kind) {
  return switch (kind) {
    CheckInKind.availableNow => 'available_now',
    CheckInKind.availableLater => 'available_later',
    CheckInKind.unavailable => 'unavailable',
  };
}

CheckInKind checkInKindFromKey(Object? key) {
  return switch (key) {
    'available_now' => CheckInKind.availableNow,
    'available_later' => CheckInKind.availableLater,
    'unavailable' => CheckInKind.unavailable,
    _ => throw const RepositoryFailure('check-in kind is not recognized'),
  };
}

DateTime _utc(Object? value, String label) {
  if (value is! String || value.isEmpty) {
    throw RepositoryFailure('check-in is missing $label');
  }
  return DateTime.parse(value).toUtc();
}

StoredCheckIn checkInFromRow(Map<String, dynamic> row) {
  final userId = row['user_id'];
  final squadId = row['squad_id'];
  if (userId is! String || squadId is! String) {
    throw const RepositoryFailure('check-in row is missing an id');
  }
  final kind = checkInKindFromKey(row['kind']);
  final checkedAt = _utc(row['checked_at'], 'checked_at');
  final DateTime? until;
  if (kind == CheckInKind.unavailable) {
    until = null;
  } else {
    until = _utc(row['until_at'], 'until_at');
  }
  return StoredCheckIn(
    userId: userId,
    squadId: squadId,
    kind: kind,
    checkedAt: checkedAt,
    until: until,
  );
}

Exception mapCheckInReadError(PostgrestException error) {
  if (_missingTable(error)) return const AvailabilityNotEnabled();
  return const RepositoryFailure('Could not load check-ins.');
}

Exception mapCheckInWriteError(PostgrestException error) {
  if (_missingTable(error)) return const AvailabilityNotEnabled();
  if (error.code == '23514' &&
      error.message.contains('sq8_check_in_later_invalid')) {
    return const RepositoryFailure(
      'Pick a time at least a minute from now and within 7 days. Nothing was saved.',
    );
  }
  if (error.code == '42501') {
    return const RepositoryFailure(
      'The server refused that check-in. Nothing was saved.',
    );
  }
  return const RepositoryFailure(
    'Could not save your check-in. Nothing was saved.',
  );
}

bool _missingTable(PostgrestException error) =>
    error.code == '42P01' || error.code == 'PGRST205';
