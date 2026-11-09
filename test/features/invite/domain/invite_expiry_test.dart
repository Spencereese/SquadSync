import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/invite/domain/invite_code.dart';

void main() {
  test('expiry is local and the code flips at that instant', () {
    final expires = DateTime.utc(2026, 11, 16, 8, 43);
    expect(
      formatInviteExpiry(expires, const Duration(hours: -6)),
      'Expires Mon Nov 16, 2:43 AM',
    );
    expect(
      formatInviteExpiry(DateTime.utc(2026, 11, 16, 12), Duration.zero),
      'Expires Mon Nov 16, 12:00 PM',
    );

    final invite = SquadInvite(
      code: 'CODE2345',
      expiresAt: DateTime.utc(2026, 11, 16, 8, 43),
      squadId: 'squad',
    );
    expect(invite.isExpired(DateTime.utc(2026, 11, 16, 8, 42)), isFalse);
    expect(invite.isExpired(expires), isTrue);
  });
}
