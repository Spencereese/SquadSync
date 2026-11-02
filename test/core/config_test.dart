import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/config.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/data/fake_auth_repository.dart';
import 'package:squadsync/features/chat/data/fake_chat_repository.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';

void main() {
  test('config is absent unless both the url and the anon key are set', () {
    expect(SquadSyncConfig.absent.isPresent, isFalse);
    expect(SquadSyncConfig.fromEnvironment().isPresent, isFalse);
    expect(
      const SquadSyncConfig(
        url: 'https://example.supabase.co',
        anonKey: '',
      ).isPresent,
      isFalse,
    );
    expect(
      const SquadSyncConfig(
        url: 'https://example.supabase.co',
        anonKey: 'public-anon-key',
      ).isPresent,
      isTrue,
    );
  });

  test('with no client the repositories stay on fakes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(squadRepositoryProvider), isA<FakeSquadRepository>());
    expect(container.read(chatRepositoryProvider), isA<FakeChatRepository>());
    expect(container.read(authRepositoryProvider), isA<FakeAuthRepository>());
  });
}
