import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:squad_sync/core/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpTheme(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
  }

  group('AppTheme.dark Material 3 tokens', () {
    testWidgets('is Material 3 dark with revival scaffold surface',
        (tester) async {
      final theme = AppTheme.dark();
      await pumpTheme(tester, theme);
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0B0E14));
      expect(theme.dialogTheme.backgroundColor, const Color(0xFF14181F));
      expect(theme.textSelectionTheme.cursorColor, isNotNull);
    });

    testWidgets('app bar uses light status-bar icons on dark surfaces',
        (tester) async {
      final overlay = AppTheme.dark().appBarTheme.systemOverlayStyle;
      await pumpTheme(tester, AppTheme.dark());
      expect(overlay?.statusBarIconBrightness, Brightness.light);
      expect(overlay?.statusBarBrightness, Brightness.dark);
    });

    testWidgets('glass fills stay light-on-dark', (tester) async {
      final theme = AppTheme.dark();
      await pumpTheme(tester, theme);
      expect(theme.cardTheme.color, Colors.white.withValues(alpha: 0.08));
      expect(
        theme.inputDecorationTheme.fillColor,
        Colors.white.withValues(alpha: 0.05),
      );
      expect(
        theme.bottomNavigationBarTheme.backgroundColor,
        Colors.white.withValues(alpha: 0.05),
      );
    });

    testWidgets('FAB glow elevation follows neonGlowEnabled', (tester) async {
      await pumpTheme(tester, AppTheme.dark());
      expect(AppTheme.dark().floatingActionButtonTheme.elevation, 8);
      expect(
        AppTheme.dark(neonGlowEnabled: false)
            .floatingActionButtonTheme
            .elevation,
        2,
      );
    });
  });

  group('AppTheme.light Material 3 tokens', () {
    testWidgets(
        'is Material 3 light with dedicated scaffold and dialog surfaces',
        (tester) async {
      final theme = AppTheme.light();
      await pumpTheme(tester, theme);
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF4F6FA));
      expect(theme.dialogTheme.backgroundColor, const Color(0xFFFFFFFF));
      expect(
        theme.dialogTheme.backgroundColor,
        isNot(AppTheme.dark().dialogTheme.backgroundColor),
      );
      expect(theme.textSelectionTheme.cursorColor, isNotNull);
      expect(theme.textTheme.bodyMedium?.color, theme.colorScheme.onSurface);
    });

    testWidgets('app bar uses dark status-bar icons on light surfaces',
        (tester) async {
      final overlay = AppTheme.light().appBarTheme.systemOverlayStyle;
      await pumpTheme(tester, AppTheme.light());
      expect(overlay?.statusBarIconBrightness, Brightness.dark);
      expect(overlay?.statusBarBrightness, Brightness.light);
    });

    testWidgets('glass fills use dark overlays instead of white-on-white',
        (tester) async {
      final theme = AppTheme.light();
      await pumpTheme(tester, theme);
      expect(theme.cardTheme.color, Colors.black.withValues(alpha: 0.04));
      expect(
        theme.inputDecorationTheme.fillColor,
        Colors.black.withValues(alpha: 0.04),
      );
      expect(
        theme.bottomNavigationBarTheme.backgroundColor,
        Colors.black.withValues(alpha: 0.04),
      );
      expect(
        theme.elevatedButtonTheme.style?.foregroundColor
            ?.resolve(const <WidgetState>{}),
        theme.colorScheme.onSurface,
      );
    });

    testWidgets('shares typography and radius tokens with dark', (tester) async {
      final light = AppTheme.light();
      final dark = AppTheme.dark();
      await pumpTheme(tester, light);
      expect(
        light.textTheme.headlineSmall?.fontSize,
        dark.textTheme.headlineSmall?.fontSize,
      );
      expect(
        light.textTheme.bodyMedium?.fontSize,
        dark.textTheme.bodyMedium?.fontSize,
      );
      final lightShape = light.cardTheme.shape as RoundedRectangleBorder;
      final darkShape = dark.cardTheme.shape as RoundedRectangleBorder;
      expect(lightShape.borderRadius, darkShape.borderRadius);
    });
  });

  group('dynamic seed and accessibility', () {
    testWidgets('seed color changes primary away from the default cyan scheme',
        (tester) async {
      final cyan = AppTheme.light();
      final red = AppTheme.light(dynamicSeedColor: const Color(0xFFFF1744));
      await pumpTheme(tester, red);
      expect(red.colorScheme.primary, isNot(cyan.colorScheme.primary));
      expect(red.textSelectionTheme.cursorColor, const Color(0xFFFF1744));
    });

    testWidgets('dynamicColorScheme is used when provided', (tester) async {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6A4C93),
        brightness: Brightness.light,
      );
      final theme = AppTheme.light(dynamicColorScheme: scheme);
      await pumpTheme(tester, theme);
      expect(theme.colorScheme.primary, scheme.primary);
    });

    testWidgets('highContrastMode sets accessible onSurface', (tester) async {
      final lightHigh = AppTheme.light(highContrastMode: true);
      final darkHigh = AppTheme.dark(highContrastMode: true);
      await pumpTheme(tester, lightHigh);
      expect(lightHigh.colorScheme.onSurface, Colors.black);
      expect(darkHigh.colorScheme.onSurface, Colors.white);
    });

    test('highContrast helper pushes mid tones to extremes', () {
      final light = AppTheme.highContrast(
        const Color(0xFFC0C0C0),
        Brightness.light,
      );
      final dark = AppTheme.highContrast(
        const Color(0xFF404040),
        Brightness.dark,
      );
      expect(HSLColor.fromColor(light).lightness, closeTo(0.1, 0.02));
      expect(HSLColor.fromColor(dark).lightness, closeTo(0.9, 0.02));
    });

    test('accessibleTextColor and WCAG helper', () {
      expect(AppTheme.accessibleTextColor(Colors.white), Colors.black);
      expect(AppTheme.accessibleTextColor(Colors.black), Colors.white);
      expect(
        AppTheme.hasSufficientContrast(Colors.black, Colors.white),
        isTrue,
      );
      expect(
        AppTheme.hasSufficientContrast(Colors.grey, Colors.grey),
        isFalse,
      );
    });
  });
}
