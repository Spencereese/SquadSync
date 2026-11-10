import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/client_id.dart';
import 'package:squadsync/core/config.dart';
import 'package:squadsync/core/supabase_sq8_database.dart';
import 'package:squadsync/features/auth/data/auth_repository.dart';
import 'package:squadsync/features/auth/data/fake_auth_repository.dart';
import 'package:squadsync/features/auth/data/supabase_auth_repository.dart';
import 'package:squadsync/features/availability/data/availability_repository.dart';
import 'package:squadsync/features/availability/data/fake_availability_repository.dart';
import 'package:squadsync/features/availability/data/supabase_availability_repository.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/invite/data/code_share.dart';
import 'package:squadsync/features/push/data/push_notifications.dart';
import 'package:squadsync/features/spot/data/fake_spot_repository.dart';
import 'package:squadsync/features/spot/data/spot_repository.dart';
import 'package:squadsync/features/spot/data/supabase_spot_repository.dart';
import 'package:squadsync/features/push/data/push_token_repository.dart';
import 'package:squadsync/features/invite/data/fake_invite_repository.dart';
import 'package:squadsync/features/invite/data/invite_repository.dart';
import 'package:squadsync/features/invite/data/supabase_invite_repository.dart';
import 'package:squadsync/features/chat/data/chat_repository.dart';
import 'package:squadsync/features/chat/data/fake_chat_repository.dart';
import 'package:squadsync/features/chat/data/supabase_chat_repository.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';
import 'package:squadsync/features/squad/data/squad_repository.dart';
import 'package:squadsync/features/squad/data/supabase_squad_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Empty unless [main] saw a URL and anon key.
final squadSyncConfigProvider = Provider<SquadSyncConfig>(
  (ref) => SquadSyncConfig.absent,
);

/// Null keeps every repository on its in-memory fake.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

/// Demo is explicit. A configured app with no client is broken, not a demo.
enum AppLink { demo, live, misconfigured }

final appLinkProvider = Provider<AppLink>((ref) {
  final config = ref.watch(squadSyncConfigProvider);
  final client = ref.watch(supabaseClientProvider);
  if (!config.isPresent) return AppLink.demo;
  if (client == null) return AppLink.misconfigured;
  return AppLink.live;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return FakeAuthRepository();
  return SupabaseAuthRepository(client.auth);
});

final squadRepositoryProvider = Provider<SquadRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return FakeSquadRepository();
  return SupabaseSquadRepository(SupabaseSq8Database(client));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return FakeChatRepository();
  return SupabaseChatRepository(SupabaseSq8Database(client), client);
});

final squadClockProvider = Provider<SquadClock>(
  (ref) => const SystemSquadClock(),
);

/// Device offset used only to display a UTC instant. Storage stays UTC.
final localOffsetProvider = Provider<Duration>(
  (ref) => DateTime.now().timeZoneOffset,
);

/// How often an open board re-reads the clock. Expiry does not wait for a reload.
final availabilityTickProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return FakeAvailabilityRepository(clock: ref.watch(squadClockProvider));
  }
  return SupabaseAvailabilityRepository(client);
});

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    final squads = ref.watch(squadRepositoryProvider);
    return FakeInviteRepository(
      squads: squads is FakeSquadRepository ? squads : null,
    );
  }
  return SupabaseInviteRepository(client);
});

final codeShareProvider = Provider<CodeShare>((ref) => PlatformCodeShare());

final spotRepositoryProvider = Provider<SpotRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return FakeSpotRepository(clock: ref.watch(squadClockProvider));
  }
  return SupabaseSpotRepository(client);
});

/// No push SDK in this install. Tests override this when they deliver a tap.
final pushNotificationsProvider = Provider<PushNotifications>(
  (ref) => const UnconfiguredPushNotifications(),
);

final pushTokenRepositoryProvider = Provider<PushTokenRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const NoopPushTokenRepository();
  return SupabasePushTokenRepository(client);
});

final clientIdFactoryProvider = Provider<ClientIdFactory>(
  (ref) => RandomClientIdFactory(),
);
