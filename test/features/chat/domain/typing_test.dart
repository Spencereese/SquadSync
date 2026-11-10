import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/chat/domain/typing.dart';

void main() {
  test('a typer drops after 4 seconds with no later event', () {
    var now = DateTime.utc(2026, 11, 10, 21);
    void Function()? pending;
    final roster = TypingRoster(
      clock: () => now,
      startTimer: (delay, callback) {
        expect(delay, const Duration(seconds: 4));
        pending = callback;
      },
    );
    var shown = <String>{};
    shown = roster.apply(
      userId: 'alex',
      typing: true,
      emit: (names) => shown = names,
    );
    expect(shown, {'alex'});

    now = now.add(const Duration(seconds: 4));
    pending?.call();
    expect(shown, isEmpty);
  });

  test('typing starts once, repeats after 2 seconds, and stops when idle', () {
    var now = DateTime.utc(2026, 11, 10, 21);
    void Function()? idle;
    final keys = TypingThrottle(
      clock: () => now,
      startTimer: (delay, callback) {
        expect(delay, const Duration(seconds: 4));
        idle = callback;
      },
    );
    final sends = <bool>[];

    bool? press() {
      return keys.key(typing: true, onIdle: () => sends.add(false));
    }

    expect(press(), isTrue);
    sends.add(true);
    expect(press(), isNull);

    now = now.add(const Duration(seconds: 2));
    expect(press(), isTrue);
    sends.add(true);

    now = now.add(const Duration(seconds: 4));
    idle?.call();
    expect(sends, [true, true, false]);
  });
}
