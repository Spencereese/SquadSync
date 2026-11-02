import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/client_id.dart';
import 'package:squadsync/core/config.dart';
import 'package:squadsync/core/supabase_sq8_database.dart';
import 'package:squadsync/features/auth/data/auth_repository.dart';
import 'package:squadsync/features/auth/data/fake_auth_repository.dart';
import 'package:squadsync/features/auth/data/supabase_auth_repository.dart';
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
  return SupabaseChatRepository(SupabaseSq8Database(client));
});

final clientIdFactoryProvider = Provider<ClientIdFactory>(
  (ref) => RandomClientIdFactory(),
);
