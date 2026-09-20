import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Slice CAP reds: freeze [LobbyNotifier] as a facade.
/// No product in this commit. Loop greens later by adding the allowlist
/// comment on `lib/presentation/notifiers/lobby_notifier.dart` only.
///
/// New lobby behavior must not land as new methods here.
/// Add methods to [LobbySeatWriter], ready-lock, peacock machines, or a
/// new notifier — not `lobby_notifier.dart`.
///
/// Public method budget is the count at tip
/// 6c3c974cd0d730d0bfbece0719097afc852a815c (M CLOSED / UX wave stop).
/// File-length allowance is comment-only (+40 vs 071257c / 3.4.154+156).
const _kNotifierSrc = 'lib/presentation/notifiers/lobby_notifier.dart';

/// Public methods + public getters on [LobbyNotifier] at 6c3c974.
const kLobbyNotifierPublicMethodBudget = 89;

/// `wc -l` of the notifier at 071257c is 2628. Comment-only +40.
const kLobbyNotifierLineBudget = 2628 + 40;

/// Builder adds this allowlist comment to the notifier (budget file):
/// `// Slice CAP: public method budget 89`
const kCapBudgetAllowlistNeedle =
    'Slice CAP: public method budget $kLobbyNotifierPublicMethodBudget';

/// Seat persist calls that must go through [LobbySeatWriter] / `_commitSeatWrite`.
const _kSeatPersistNeedles = [
  '_repository.assignSpot',
  '_repository.joinLobby',
  '_repository.leaveLobby',
  '_repository.startSpotTimer',
  '_repository.processExpiredTimers',
];

/// Unrouted seat writes already on the 6c3c974 blob. Do not add more.
const _kFrozenUnroutedSeatWrites = {
  'claimSpot',
  'unclaimSpotSimple',
  'leaveLobby',
};

final _typeNames = {
  'Future',
  'List',
  'Map',
  'Set',
  'Stream',
  'Function',
};

String _notifierSource() => File(_kNotifierSrc).readAsStringSync();

int _lineCount(String src) {
  if (src.isEmpty) return 0;
  final newlines = '\n'.allMatches(src).length;
  return src.endsWith('\n') ? newlines : newlines + 1;
}

String _stripComments(String src) {
  final noBlock = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final out = StringBuffer();
  for (final line in noBlock.split('\n')) {
    var inSingle = false;
    var inDouble = false;
    var cut = line.length;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (!inSingle && !inDouble && i + 1 < line.length && ch == '/' && line[i + 1] == '/') {
        cut = i;
        break;
      }
      if (ch == "'" && !inDouble) inSingle = !inSingle;
      if (ch == '"' && !inSingle) inDouble = !inDouble;
    }
    out.writeln(line.substring(0, cut));
  }
  return out.toString();
}

String _lobbyNotifierClassBody(String src) {
  const needle = 'class LobbyNotifier ';
  final start = src.indexOf(needle);
  expect(start, isNonNegative, reason: 'LobbyNotifier class missing in $_kNotifierSrc');
  final brace = src.indexOf('{', start);
  expect(brace, isNonNegative, reason: 'LobbyNotifier has no body');
  var depth = 0;
  for (var i = brace; i < src.length; i++) {
    final ch = src[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return src.substring(start, i + 1);
    }
  }
  fail('unbalanced LobbyNotifier class body');
}

class _PublicApi {
  const _PublicApi(this.methods, this.getters);
  final List<String> methods;
  final List<String> getters;
  List<String> get all => [...methods, ...getters];
}

/// Class-level public methods and getters (indent exactly 2).
_PublicApi _publicApi(String classSrc) {
  final cleaned = _stripComments(classSrc);
  final methods = <String>[];
  final getters = <String>[];
  for (final line in cleaned.split('\n')) {
    if (!RegExp(r'^  \S').hasMatch(line)) continue;
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('@')) continue;
    if (trimmed.contains(' Function(')) continue;

    final getter = RegExp(r'\bget\s+([A-Za-z_][A-Za-z0-9_]*)\b').firstMatch(line);
    if (getter != null && !line.split('get').first.contains('(')) {
      final name = getter.group(1)!;
      if (!name.startsWith('_')) getters.add(name);
      continue;
    }

    final ids = RegExp(r'\b([A-Za-z_][A-Za-z0-9_]*)\s*\(').allMatches(line);
    String? name;
    for (final match in ids) {
      final ident = match.group(1)!;
      if (!_typeNames.contains(ident)) {
        name = ident;
        break;
      }
    }
    if (name != null && !name.startsWith('_')) methods.add(name);
  }
  return _PublicApi(methods, getters);
}

String _methodBody(String classSrc, String name) {
  final match = RegExp(
    '(?:^|\\n)  (?:@[\\w.]+\\n  )*[\\w.<>,\\s\\?]+\\s+$name\\s*\\(',
  ).firstMatch(classSrc);
  if (match == null) {
    fail('public method $name missing from LobbyNotifier');
  }
  final from = match.start;
  final arrow = classSrc.indexOf('=>', match.end);
  final brace = classSrc.indexOf('{', match.end);
  if (arrow >= 0 && (brace < 0 || arrow < brace)) {
    final end = classSrc.indexOf(';', arrow);
    expect(end, isNonNegative, reason: '$name => body has no semicolon');
    return classSrc.substring(from, end + 1);
  }
  expect(brace, isNonNegative, reason: '$name has no body');
  var depth = 0;
  for (var i = brace; i < classSrc.length; i++) {
    final ch = classSrc[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return classSrc.substring(from, i + 1);
    }
  }
  fail('unbalanced body for $name');
}

bool _persistsSeat(String body) =>
    _kSeatPersistNeedles.any(body.contains);

void main() {
  group('Slice CAP — LobbyNotifier facade method budget', () {
    test('budget file records the 6c3c974 public method allowlist', () {
      final src = _notifierSource();
      expect(
        File(_kNotifierSrc).existsSync(),
        isTrue,
        reason: 'Budget file $_kNotifierSrc is missing.',
      );
      expect(
        src.contains(kCapBudgetAllowlistNeedle),
        isTrue,
        reason: 'Budget file is missing the Slice CAP allowlist comment. '
            'Builder: add `// $kCapBudgetAllowlistNeedle` to $_kNotifierSrc. '
            'Do not add new public methods on LobbyNotifier.',
      );
    });

    test('public method count does not exceed the 6c3c974 budget', () {
      final api = _publicApi(_lobbyNotifierClassBody(_notifierSource()));
      expect(
        api.all.length,
        lessThanOrEqualTo(kLobbyNotifierPublicMethodBudget),
        reason: 'LobbyNotifier public method count is ${api.all.length}, '
            'budget is $kLobbyNotifierPublicMethodBudget (tip 6c3c974). '
            'Add methods to LobbySeatWriter, ready-lock, peacock machines, '
            'or a new notifier — not here. Extra: ${api.all}',
      );
    });

    test('file length stays within comment-only +40 allowance', () {
      final lines = _lineCount(_notifierSource());
      expect(
        lines,
        lessThanOrEqualTo(kLobbyNotifierLineBudget),
        reason: '$_kNotifierSrc is $lines lines; budget is '
            '$kLobbyNotifierLineBudget (2628 at 071257c + 40 comments).',
      );
    });

    test('new seat-write paths call LobbySeatWriter / _commitSeatWrite', () {
      final classSrc = _lobbyNotifierClassBody(_notifierSource());
      final names = _publicApi(classSrc).methods;
      final newcomers = <String>[];
      for (final name in names) {
        if (_kFrozenUnroutedSeatWrites.contains(name)) continue;
        final body = _methodBody(classSrc, name);
        if (_persistsSeat(body) && !body.contains('_commitSeatWrite')) {
          newcomers.add(name);
        }
      }
      expect(
        newcomers,
        isEmpty,
        reason: 'New seat-write path(s) $newcomers must call '
            'LobbySeatWriter / _commitSeatWrite. Do not add a second writer '
            'on LobbyNotifier.',
      );
    });
  });
}
