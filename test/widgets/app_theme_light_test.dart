import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:squad_sync/core/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('light theme paints Material 3 scaffold and on-surface copy',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Text('theme-light'),
        ),
      ),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
    expect(materialApp.theme?.brightness, Brightness.light);

    final context = tester.element(find.text('theme-light'));
    final theme = Theme.of(context);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF4F6FA));
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.textTheme.bodyMedium?.color, theme.colorScheme.onSurface);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark theme still paints revival neon-dark scaffold',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Text('theme-dark'),
        ),
      ),
    );

    final context = tester.element(find.text('theme-dark'));
    final theme = Theme.of(context);
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0B0E14));
    expect(tester.takeException(), isNull);
  });

  testWidgets('light glass card uses a dark overlay, dark uses a light overlay',
      (tester) async {
    late BoxDecoration lightGlass;
    late BoxDecoration darkGlass;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            lightGlass = Theme.of(context).glassyCard(
              adaptToBackground: const Color(0xFFFFFFFF),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            darkGlass = Theme.of(context).glassyCard(
              adaptToBackground: const Color(0xFF0B0E14),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(lightGlass.color, Colors.black.withValues(alpha: 0.35));
    expect(darkGlass.color, Colors.white.withValues(alpha: 0.08));
    expect(lightGlass.color, isNot(darkGlass.color));
  });

  testWidgets('GlassmorphicContainer renders under light and dark themes',
      (tester) async {
    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: GlassmorphicContainer(
              adaptToBackground: theme.scaffoldBackgroundColor,
              child: const Text('glass-child'),
            ),
          ),
        ),
      );
      expect(find.text('glass-child'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await pump(AppTheme.light());
    await pump(AppTheme.dark());
  });
}
