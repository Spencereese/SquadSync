import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/widgets/login_brand.dart';

void main() {
  testWidgets('Forgot password is fully visible in a 390-wide box',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: ForgotPasswordButton(onPressed: null),
          ),
        ),
      ),
    );

    expect(find.text('Forgot password?'), findsOneWidget);

    final text = tester.widget<Text>(find.text('Forgot password?'));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(text.maxLines, 2);
    expect(text.data, contains('password?'));

    final paragraph =
        tester.renderObject<RenderParagraph>(find.text('Forgot password?'));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.text.toPlainText(), 'Forgot password?');
  });

  testWidgets('peacock logo is on screen at 390 and 1440', (tester) async {
    for (final size in const [Size(390, 844), Size(1440, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: const SingleChildScrollView(
                  child: LoginBrandHeader(neon: Color(0xFF00F5FF)),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(LoginBrandHeader.logoKey),
        findsOneWidget,
        reason: 'logo missing at ${size.width}x${size.height}',
      );
      expect(find.text('Cod Squad'), findsOneWidget);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
