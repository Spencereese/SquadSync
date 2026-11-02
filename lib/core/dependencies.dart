import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/client_id.dart';
import 'package:squadsync/features/chat/data/chat_repository.dart';
import 'package:squadsync/features/chat/data/fake_chat_repository.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';
import 'package:squadsync/features/squad/data/squad_repository.dart';

/// Slice 1 composition root. The app talks to fakes only.
/// A later slice swaps these constructors for Supabase. Widgets do not.
final squadRepositoryProvider = Provider<SquadRepository>(
  (ref) => FakeSquadRepository(),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => FakeChatRepository(),
);

final clientIdFactoryProvider = Provider<ClientIdFactory>(
  (ref) => RandomClientIdFactory(),
);
