import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/services.dart';
import '../chat/chat_service.dart';
import '../managers/sync_manager.dart';

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Service Providers for consolidated notifiers
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final mediaServiceProvider = Provider<MediaService>((ref) => MediaService());
final pollServiceProvider = Provider<PollService>((ref) => PollService());
final aiServiceProvider = Provider<AiService>((ref) => AiService());
final igdbAuthServiceProvider =
    Provider<IgdbAuthService>((ref) => IgdbAuthService());
final igdbServiceProvider = Provider<IgdbService>((ref) {
  final sqliteHelper = ref.watch(sqliteHelperProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  return IgdbService(sqliteHelper, firestoreService);
});
final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());
final messageServiceProvider =
    Provider<MessageService>((ref) => MessageService());
final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());
final syncManagerProvider = Provider<SyncManager>((ref) => SyncManager(sqliteHelper: ref.watch(sqliteHelperProvider)));
final chatServiceProvider = Provider((ref) => ChatService(ref.watch(syncManagerProvider)));
final reactionServiceProvider =
    Provider<ReactionService>((ref) => ReactionService());
// timerServiceProvider is defined in timer_service.dart
final grokServiceProvider = Provider<GrokService>((ref) => GrokService());
