import 'dart:async';

/// People who sent a typing broadcast. A person drops after [window] even
/// when no later event arrives.
class TypingRoster {
  TypingRoster({
    DateTime Function()? clock,
    void Function(Duration delay, void Function() callback)? startTimer,
  }) : _clock = clock ?? DateTime.now,
       _later = _Later(startTimer);

  static const window = Duration(seconds: 4);

  final DateTime Function() _clock;
  final _Later _later;
  final Map<String, DateTime> _seen = {};
  void Function(Set<String> names)? _emit;

  Set<String> apply({
    required String userId,
    required bool typing,
    required void Function(Set<String> names) emit,
  }) {
    _emit = emit;
    if (userId.isNotEmpty) {
      if (typing) {
        _seen[userId] = _clock();
      } else {
        _seen.remove(userId);
      }
    }
    return _arm();
  }

  void dispose() {
    _emit = null;
    _later.cancel();
  }

  Set<String> _arm() {
    final now = _clock();
    _seen.removeWhere((_, at) => now.difference(at) >= window);
    final names = Set<String>.of(_seen.keys);
    if (_seen.isEmpty) {
      _later.cancel();
      return names;
    }
    var wait = window;
    for (final at in _seen.values) {
      final left = window - now.difference(at);
      if (left < wait) wait = left;
    }
    if (wait.isNegative) wait = Duration.zero;
    _later.schedule(wait, () {
      final left = _arm();
      _emit?.call(left);
    });
    return names;
  }
}

/// Sends one start, then at most one repeat per [repeat] while keys are
/// pressed, then one stop after [idle] with no keystroke.
class TypingThrottle {
  TypingThrottle({
    this.repeat = const Duration(seconds: 2),
    this.idle = const Duration(seconds: 4),
    DateTime Function()? clock,
    void Function(Duration delay, void Function() callback)? startTimer,
  }) : _clock = clock ?? DateTime.now,
       _later = _Later(startTimer);

  final Duration repeat;
  final Duration idle;
  final DateTime Function() _clock;
  final _Later _later;
  var _on = false;
  DateTime? _sentAt;

  /// `true` to announce typing, `false` to announce a stop, null to skip.
  bool? key({required bool typing, required void Function() onIdle}) {
    if (!typing) {
      _later.cancel();
      if (!_on) return null;
      _on = false;
      _sentAt = null;
      return false;
    }
    _later.schedule(idle, () {
      if (!_on) return;
      _on = false;
      _sentAt = null;
      onIdle();
    });
    final now = _clock();
    if (_on && _sentAt != null && now.difference(_sentAt!) < repeat) {
      return null;
    }
    _on = true;
    _sentAt = now;
    return true;
  }

  /// True when a stop still needs to be sent.
  bool stop() {
    _later.cancel();
    final was = _on;
    _on = false;
    _sentAt = null;
    return was;
  }
}

const originalMessageUnavailable = 'Original message unavailable';

class _Later {
  _Later(this._injected);

  final void Function(Duration delay, void Function() callback)? _injected;
  Timer? _timer;
  var _generation = 0;

  void schedule(Duration delay, void Function() callback) {
    cancel();
    final generation = ++_generation;
    void fire() {
      if (generation != _generation) return;
      callback();
    }

    final injected = _injected;
    if (injected == null) {
      _timer = Timer(delay, fire);
    } else {
      injected(delay, fire);
    }
  }

  void cancel() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }
}
