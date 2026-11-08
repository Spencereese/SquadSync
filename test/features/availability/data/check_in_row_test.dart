import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/availability/data/availability_repository.dart';
import 'package:squadsync/features/availability/data/check_in_row.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('a row keeps utc times and does not invent a kind', () {
    final row = checkInFromRow({
      'user_id': 'spencer',
      'squad_id': 'squad',
      'kind': 'available_later',
      'checked_at': '2026-11-08T15:00:00.000Z',
      'until_at': '2026-11-08T20:00:00.000Z',
    });
    expect(row.kind, CheckInKind.availableLater);
    expect(row.checkedAt, DateTime.utc(2026, 11, 8, 15));
    expect(row.until, DateTime.utc(2026, 11, 8, 20));
    expect(row.checkedAt.isUtc, isTrue);

    expect(
      () => checkInFromRow({
        'user_id': 'spencer',
        'squad_id': 'squad',
        'kind': 'online',
        'checked_at': '2026-11-08T15:00:00.000Z',
      }),
      throwsA(isA<RepositoryFailure>()),
    );
  });

  test('a missing table is not a successful empty read or a saved write', () {
    expect(
      mapCheckInReadError(
        const PostgrestException(message: 'missing', code: 'PGRST205'),
      ),
      isA<AvailabilityNotEnabled>(),
    );
    expect(
      mapCheckInWriteError(
        const PostgrestException(message: 'missing', code: '42P01'),
      ),
      isA<AvailabilityNotEnabled>(),
    );
    expect(
      mapCheckInWriteError(
        const PostgrestException(
          message: 'sq8_check_in_later_invalid',
          code: '23514',
        ),
      ),
      isA<RepositoryFailure>().having(
        (error) => error.message,
        'message',
        contains('Nothing was saved'),
      ),
    );
  });
}
