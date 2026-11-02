import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/client_id.dart';

void main() {
  test('client ids are unique uuid-shaped strings', () {
    final factory = RandomClientIdFactory(random: Random(1));
    final first = factory.create();
    final second = factory.create();

    expect(first, isNot(second));
    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('a sequence factory returns each id once', () {
    final factory = SequenceClientIdFactory(['msg-1', 'msg-2']);

    expect(factory.create(), 'msg-1');
    expect(factory.create(), 'msg-2');
    expect(factory.create, throwsStateError);
  });
}
