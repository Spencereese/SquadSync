import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/layout.dart';

void main() {
  test('mainTabClearance is tab bar height plus the home-indicator inset', () {
    expect(kMainTabBarHeight, 75);
    expect(mainTabClearance(0), kMainTabBarHeight);
    expect(mainTabClearance(34), kMainTabBarHeight + 34);
  });

  testWidgets('mainTabClearanceOf reads MediaQuery.viewPadding.bottom',
      (tester) async {
    late double clearance;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: 34),
          viewPadding: EdgeInsets.only(bottom: 34),
        ),
        child: Builder(
          builder: (context) {
            clearance = mainTabClearanceOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(clearance, kMainTabBarHeight + 34);
  });

  testWidgets('list padding and SafeArea share the same tab clearance',
      (tester) async {
    const inset = 34.0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: inset),
          viewPadding: EdgeInsets.only(bottom: inset),
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ListView(
                  padding: EdgeInsets.only(bottom: mainTabClearanceOf(context)),
                  children: const [SizedBox(height: 8, key: Key('row'))],
                ),
              );
            },
          ),
        ),
      ),
    );

    final list = tester.widget<ListView>(find.byType(ListView));
    final padding = list.padding as EdgeInsets?;
    expect(padding?.bottom, kMainTabBarHeight + inset);
  });
}
