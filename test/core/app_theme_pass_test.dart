import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:squad_sync/core/app_theme.dart';

/// Slice N reds: AppTheme pass. Files stay; no product in this commit.
/// Loop greens later in `lib/core/app_theme.dart` only (keep `dark()` / `light()`).
///
/// Contract:
/// - titleSmall / titleMedium / label* → Inter (not Orbitron)
/// - elevatedButton: filled primary, onPrimary contrast, no glass default
/// - card: surface, 1px border @ 12% white, radius 16 (not 20 + neon)
/// - Do not delete [ThemeData.glassyCard]
/// - Friends home / seat stop calling glassyCard
/// - Chat bubbles unchanged
const _kThemeSrc = 'lib/core/app_theme.dart';
const _kChatBubbleSrc = 'lib/chat/message_bubble.dart';

const _kFriendsHomeSeatLibPaths = [
  'lib/screens/lobby_tab_screen.dart',
  'lib/lobbies_tab/lobbies_tab.dart',
  'lib/screens/tonight_home.dart',
  'lib/lobbies_tab/widgets/tonight_home.dart',
  'lib/widgets/tonight_home.dart',
  'lib/lobbies_tab/widgets/lobby_controls.dart',
  'lib/lobbies_tab/widgets/lobby_seat_affordance.dart',
  'lib/lobbies_tab/widgets/lobby_spot_map_seat.dart',
];

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Slice N — titleSmall / titleMedium / label* Inter', () {
    test('text theme source maps titleSmall/titleMedium/label* to Inter', () {
      final src = File(_kThemeSrc).readAsStringSync();
      expect(_googleFontForRole(src, 'titleSmall'), 'inter');
      expect(_googleFontForRole(src, 'titleMedium'), 'inter');
      expect(_googleFontForRole(src, 'labelLarge'), 'inter');
      expect(_googleFontForRole(src, 'labelMedium'), 'inter');
      expect(_googleFontForRole(src, 'labelSmall'), 'inter');
      expect(_googleFontForRole(src, 'titleSmall'), isNot('orbitron'));
      expect(_googleFontForRole(src, 'titleMedium'), isNot('orbitron'));
    });

    testWidgets('dark + light titleSmall/titleMedium/label* resolve Inter',
        (tester) async {
      for (final theme in [AppTheme.dark(), AppTheme.light()]) {
        await _pumpTheme(tester, theme);
        for (final style in [
          theme.textTheme.titleSmall,
          theme.textTheme.titleMedium,
          theme.textTheme.labelLarge,
          theme.textTheme.labelMedium,
          theme.textTheme.labelSmall,
        ]) {
          expect(
            _isInter(style),
            isTrue,
            reason: '${style?.fontSize}pt role must be Inter, got '
                '${style?.fontFamily}',
          );
          expect(
            _isOrbitron(style),
            isFalse,
            reason: 'titleSmall / titleMedium / label* must not stay Orbitron',
          );
        }
      }
    });
  });

  group('Slice N — elevatedButton filled primary, no glass', () {
    testWidgets('dark elevatedButton is filled primary with onPrimary contrast',
        (tester) async {
      final theme = AppTheme.dark();
      await _pumpTheme(tester, theme);
      _expectFilledPrimaryButton(theme);
    });

    testWidgets('light elevatedButton is filled primary with onPrimary contrast',
        (tester) async {
      final theme = AppTheme.light();
      await _pumpTheme(tester, theme);
      _expectFilledPrimaryButton(theme);
    });

    testWidgets('pumped ElevatedButton paints primary fill, not glass',
        (tester) async {
      final theme = AppTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Go'),
            ),
          ),
        ),
      );

      final materials = tester.widgetList<Material>(find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(Material),
      ));
      expect(materials, isNotEmpty);
      expect(
        materials.any((m) => m.color == theme.colorScheme.primary),
        isTrue,
        reason: 'ElevatedButton default must be filled primary, not glass',
      );
      expect(
        materials.any((m) =>
            m.color == Colors.white.withValues(alpha: 0.08) ||
            m.color == Colors.black.withValues(alpha: 0.04)),
        isFalse,
        reason: 'No glass default on ElevatedButton',
      );
    });
  });

  group('Slice N — card surface, 1px 12% white, radius 16', () {
    testWidgets('dark card is surface + 16 + 1px 12% white, not 20 + neon',
        (tester) async {
      final theme = AppTheme.dark();
      await _pumpTheme(tester, theme);
      _expectSurfaceCard(theme);
    });

    testWidgets('light card is surface + 16 + 1px 12% white, not 20 + neon',
        (tester) async {
      final theme = AppTheme.light();
      await _pumpTheme(tester, theme);
      _expectSurfaceCard(theme);
    });

    testWidgets('pumped Card uses radius 16 and surface, not neon glass 20',
        (tester) async {
      final theme = AppTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Card(child: SizedBox(width: 48, height: 48)),
          ),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color ?? theme.cardTheme.color, theme.colorScheme.surface);
      final shape = (card.shape ?? theme.cardTheme.shape) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
      expect(shape.side.width, 1);
      expect(shape.side.color, Colors.white.withValues(alpha: 0.12));
      expect(shape.borderRadius, isNot(BorderRadius.circular(20)));
      expect(shape.side.width, isNot(1.5));
    });
  });

  group('Slice N — keep dark()/light() and glassyCard', () {
    test('dark() and light() APIs still return ThemeData', () {
      expect(AppTheme.dark(), isA<ThemeData>());
      expect(AppTheme.light(), isA<ThemeData>());
      expect(AppTheme.dark().brightness, Brightness.dark);
      expect(AppTheme.light().brightness, Brightness.light);
    });

    testWidgets('glassyCard helper remains opt-in glass (not deleted)',
        (tester) async {
      late BoxDecoration glass;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              glass = Theme.of(context).glassyCard(
                adaptToBackground: const Color(0xFF0B0E14),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(glass, isA<BoxDecoration>());
      expect(glass.borderRadius, BorderRadius.circular(20));
      expect(glass.color, Colors.white.withValues(alpha: 0.08));
    });
  });

  group('Slice N — friends home/seat stop calling glassyCard', () {
    test('friends home and seat sources do not call glassyCard', () {
      for (final path in _kFriendsHomeSeatLibPaths) {
        final file = File(path);
        if (!file.existsSync()) continue;
        expect(
          file.readAsStringSync().contains('glassyCard'),
          isFalse,
          reason: '$path must not call glassyCard after AppTheme pass',
        );
      }
    });
  });

  group('Slice N — chat bubbles unchanged', () {
    test('message_bubble keeps iMessage glass pills, not Card tokens', () {
      final src = File(_kChatBubbleSrc).readAsStringSync();
      expect(src.contains('BackdropFilter'), isTrue);
      expect(src.contains('0xFF007AFF'), isTrue);
      expect(src.contains('0xFF3C3C3E'), isTrue);
      expect(src.contains('sigmaX: 30'), isTrue);
      expect(src.contains('Colors.white.withValues(alpha: 0.2)'), isTrue);
      expect(src.contains('width: 0.5'), isTrue);
      expect(
        src.contains('cardTheme') || src.contains('AppTheme.dark().cardTheme'),
        isFalse,
        reason: 'Chat bubbles must not adopt the new Card theme',
      );
    });
  });
}

Future<void> _pumpTheme(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
}

String _googleFontForRole(String src, String role) {
  final match = RegExp('$role:\\s*GoogleFonts\\.(\\w+)').firstMatch(src);
  expect(match, isNotNull, reason: 'missing GoogleFonts mapping for $role');
  return match!.group(1)!;
}

bool _isInter(TextStyle? style) {
  final family = style?.fontFamily ?? '';
  final fallback = style?.fontFamilyFallback ?? const <String>[];
  return family.contains('Inter') ||
      fallback.any((name) => name.contains('Inter'));
}

bool _isOrbitron(TextStyle? style) {
  final family = style?.fontFamily ?? '';
  final fallback = style?.fontFamilyFallback ?? const <String>[];
  return family.contains('Orbitron') ||
      fallback.any((name) => name.contains('Orbitron'));
}

void _expectFilledPrimaryButton(ThemeData theme) {
  final style = theme.elevatedButtonTheme.style;
  expect(style, isNotNull);
  final empty = <WidgetState>{};
  final background = style!.backgroundColor?.resolve(empty);
  final foreground = style.foregroundColor?.resolve(empty);
  expect(
    background,
    theme.colorScheme.primary,
    reason: 'elevatedButton default fill is primary, not glass',
  );
  expect(
    foreground,
    theme.colorScheme.onPrimary,
    reason: 'elevatedButton label uses onPrimary contrast',
  );
  expect(
    background,
    isNot(Colors.white.withValues(alpha: 0.08)),
  );
  expect(
    background,
    isNot(Colors.black.withValues(alpha: 0.04)),
  );
  final side = style.side?.resolve(empty);
  expect(
    side == null || side.width == 0 || side.color.a == 0,
    isTrue,
    reason: 'filled primary has no neon/glass outline by default',
  );
}

void _expectSurfaceCard(ThemeData theme) {
  expect(
    theme.cardTheme.color,
    theme.colorScheme.surface,
    reason: 'card fill is surface, not glass',
  );
  expect(theme.cardTheme.color, isNot(Colors.white.withValues(alpha: 0.08)));
  expect(theme.cardTheme.color, isNot(Colors.black.withValues(alpha: 0.04)));

  final shape = theme.cardTheme.shape;
  expect(shape, isA<RoundedRectangleBorder>());
  final rounded = shape! as RoundedRectangleBorder;
  expect(
    rounded.borderRadius,
    BorderRadius.circular(16),
    reason: 'card radius 16, not 20',
  );
  expect(rounded.borderRadius, isNot(BorderRadius.circular(20)));
  expect(rounded.side.width, 1, reason: '1px border, not 1.5 neon');
  expect(
    rounded.side.color,
    Colors.white.withValues(alpha: 0.12),
    reason: '1px border @ 12% white, not neon primary',
  );
  expect(
    rounded.side.color,
    isNot(theme.colorScheme.primary.withValues(alpha: 0.4)),
  );
}
