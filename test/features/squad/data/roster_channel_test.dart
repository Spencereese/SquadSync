import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/squad/data/roster_channel.dart';

void main() {
  test('a reconnect detaches the old topic and a dispose does not leak', () {
    final attached = <String>[];
    final detached = <String>[];
    final channel = RosterChannel(attach: attached.add, detach: detached.add);

    channel.bind(userId: 'spencer');
    expect(attached, ['sq8-seat-spencer']);
    expect(detached, isEmpty);

    channel.bind(userId: 'spencer');
    expect(attached, ['sq8-seat-spencer']);

    channel.resubscribe();
    expect(detached, ['sq8-seat-spencer']);
    expect(attached, ['sq8-seat-spencer', 'sq8-seat-spencer']);

    channel.bind(squadId: 'squad', userId: 'spencer');
    expect(detached, ['sq8-seat-spencer', 'sq8-seat-spencer']);
    expect(attached.last, 'sq8-squad-squad');

    channel.dispose();
    channel.dispose();
    expect(detached.last, 'sq8-squad-squad');
    expect(detached.where((topic) => topic == 'sq8-squad-squad'), hasLength(1));
  });
}
