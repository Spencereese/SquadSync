import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/invite/data/invite_repository.dart';
import 'package:squadsync/features/invite/domain/invite_code.dart';

class InviteState {
  const InviteState({
    this.loading = false,
    this.notEnabled = false,
    this.invite,
    this.error,
    this.busy = false,
  });

  final bool loading;
  final bool notEnabled;
  final SquadInvite? invite;
  final String? error;
  final bool busy;

  InviteState copyWith({
    bool? loading,
    bool? notEnabled,
    SquadInvite? invite,
    bool clearInvite = false,
    String? error,
    bool clearError = false,
    bool? busy,
  }) {
    return InviteState(
      loading: loading ?? this.loading,
      notEnabled: notEnabled ?? this.notEnabled,
      invite: clearInvite ? null : (invite ?? this.invite),
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

final inviteControllerProvider =
    NotifierProvider<InviteController, InviteState>(InviteController.new);

class InviteController extends Notifier<InviteState> {
  @override
  InviteState build() => const InviteState();

  Future<void> load() async {
    state = const InviteState(loading: true);
    try {
      final invite = await ref.read(inviteRepositoryProvider).current();
      state = InviteState(invite: invite);
    } on InvitesNotEnabled {
      state = const InviteState(notEnabled: true);
    } on Object {
      state = const InviteState(error: 'Could not load the invite.');
    }
  }

  Future<void> rotate() async {
    if (state.notEnabled || state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final invite = await ref.read(inviteRepositoryProvider).createOrRotate();
      state = InviteState(invite: invite);
    } on InvitesNotEnabled {
      state = const InviteState(notEnabled: true);
    } on Object {
      state = state.copyWith(
        busy: false,
        error: 'Could not make a code. Nothing was changed.',
      );
    }
  }

  Future<JoinDecision> join(String code) async {
    try {
      return await ref.read(inviteRepositoryProvider).join(code);
    } on InvitesNotEnabled {
      return const JoinDecision.notEnabled();
    }
  }
}
