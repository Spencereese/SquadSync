import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/dialogs/constitution_voting_sheet.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/domain/entities/constitution.dart';
import 'package:squad_sync/services/constitution_manager.dart';

void main() {
  testWidgets('voting sheet uses injected constitutionManagerProvider',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final manager = _FakeConstitutionManager();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          constitutionManagerProvider.overrideWithValue(manager),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ConstitutionVotingSheet(
              vote: ConstitutionVote(
                id: 'vote-1',
                constitutionId: 'c1',
                chatGroupId: 'g1',
                proposedRules: const {'mic_required': true},
                proposedBy: 'u2',
                expiresAt: DateTime.now().add(const Duration(hours: 2)),
                createdAt: DateTime.now(),
              ),
              chatGroupId: 'g1',
              onDismiss: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Constitution Vote'), findsOneWidget);
    expect(find.text('Vote Yes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeConstitutionManager extends Fake implements ConstitutionManager {
  @override
  String? get currentUserId => 'u1';

  @override
  Future<void> submitVote({
    required ConstitutionVote vote,
    required bool yes,
  }) async {}
}
