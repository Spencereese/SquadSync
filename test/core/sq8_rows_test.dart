import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/sq8_rows.dart';
import 'package:squadsync/core/supabase_sq8_database.dart';
import 'package:squadsync/core/sq8_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('paging filters keep the timestamp and id', () {
    final at = DateTime.utc(2026, 11, 2, 12);
    expect(
      olderThanFilter(at, 'msg-1'),
      'sent_at.lt.2026-11-02T12:00:00.000Z,and(sent_at.eq.2026-11-02T12:00:00.000Z,id.lt.msg-1)',
    );
    expect(
      newerThanFilter(at, 'msg-1'),
      'sent_at.gt.2026-11-02T12:00:00.000Z,and(sent_at.eq.2026-11-02T12:00:00.000Z,id.gt.msg-1)',
    );
    expect(newerThanFilter(at, null), 'sent_at.gt.2026-11-02T12:00:00.000Z');
  });

  test('a member row reads the embedded profile', () {
    final member = memberFromRow({
      'user_id': 'spencer',
      'sq8_profiles': {
        'display_name': 'Spencer',
        'default_game': 'Call of Duty',
      },
    });

    expect(member.userId, 'spencer');
    expect(member.displayName, 'Spencer');
    expect(member.defaultGame, 'Call of Duty');
  });

  test('a message row keeps the client id', () {
    final message = messageFromRow({
      'id': 'msg-1',
      'squad_id': 'squad',
      'sender_id': 'spencer',
      'body': 'hello',
      'sent_at': '2026-11-02T12:00:00.000Z',
    });

    expect(message.id, 'msg-1');
    expect(message.sentAt, DateTime.utc(2026, 11, 2, 12));
  });

  test('postgrest errors map onto duplicate, full, and owner', () {
    expect(
      mapPostgrest(const PostgrestException(message: 'dup', code: '23505')),
      isA<Sq8DuplicateRow>(),
    );
    expect(
      mapPostgrest(const PostgrestException(message: 'sq8_squad_full')),
      isA<Sq8SquadFull>(),
    );
    expect(
      mapPostgrest(const PostgrestException(message: 'sq8_owner_protected')),
      isA<Sq8OwnerProtected>(),
    );
  });
}
