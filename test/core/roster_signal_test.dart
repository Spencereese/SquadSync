import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/sq8_database.dart';
import 'package:squadsync/core/supabase_sq8_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('a member delete is a delete signal and other events are changes', () {
    expect(rosterSignalFor(PostgresChangeEvent.delete), RosterSignal.deleted);
    expect(rosterSignalFor(PostgresChangeEvent.insert), RosterSignal.changed);
    expect(rosterSignalFor(PostgresChangeEvent.update), RosterSignal.changed);
  });
}
