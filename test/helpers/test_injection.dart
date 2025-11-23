import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/core/injection.dart' as di;
import 'package:squad_sync/domain/repositories/system_repository.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/data/datasources/system_local_datasource.dart';
import 'package:squad_sync/data/datasources/system_remote_datasource.dart';
import 'package:squad_sync/data/datasources/squad_local_datasource.dart';
import 'package:squad_sync/data/datasources/squad_remote_datasource.dart';
import 'mocks.mocks.dart';

/// Setup mock dependencies for testing
void setupTestDependencies() {
  final getIt = GetIt.instance;

  // Reset get_it for clean tests
  getIt.reset();

  // Register mocks
  getIt.registerLazySingleton<UserLocalDataSource>(
    () => MockUserLocalDataSource(),
  );
  getIt.registerLazySingleton<UserRemoteDataSource>(
    () => MockUserRemoteDataSource(),
  );
  getIt.registerLazySingleton<UserRepository>(
    () => MockUserRepository(),
  );
  getIt.registerLazySingleton<GameRepository>(
    () => MockGameRepository(),
  );
  getIt.registerLazySingleton<SystemRepository>(
    () => MockSystemRepository(),
  );
  getIt.registerLazySingleton<SquadRepository>(
    () => MockSquadRepository(),
  );
  getIt.registerLazySingleton<ChatRepository>(
    () => MockChatRepository(),
  );
  getIt.registerLazySingleton<SystemLocalDataSource>(
    () => MockSystemLocalDataSource(),
  );
  getIt.registerLazySingleton<SystemRemoteDataSource>(
    () => MockSystemRemoteDataSource(),
  );
  getIt.registerLazySingleton<SquadLocalDataSource>(
    () => MockSquadLocalDataSource(),
  );
  getIt.registerLazySingleton<SquadRemoteDataSource>(
    () => MockSquadRemoteDataSource(),
  );
}
