import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:riverpod_test/riverpod_test.dart';
import 'package:dartz/dartz.dart';
import 'package:squad_sync/presentation/notifiers/squad_notifier.dart';
import 'package:squad_sync/domain/entities/squad.dart';
import 'package:squad_sync/core/error/failures.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late MockSquadRepository mockRepository;

  setUp(() {
    mockRepository = MockSquadRepository();
  });

  final testSquad = Squad(
    id: 'squad123',
    name: 'Test Squad',
    memberUids: ['uid1', 'uid2'],
    gameName: 'cod',
    maxSpots: 4,
    createdBy: 'uid1',
    createdAt: DateTime.now(),
    spots: [null, 'uid1', null, null],
    spotTimers: [null, null, null, null],
    viewers: [],
    statuses: {},
    isActive: true,
  );

  group('SquadNotifier', () {
    group('createSquad', () {
      testNotifier(
        'should create squad successfully',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.createSquad(any)).thenAnswer((_) async => Right(testSquad));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.createSquad(testSquad),
        expect: () => [
          const AsyncValue.loading(),
          AsyncValue.data(testSquad),
        ],
      );

      testNotifier(
        'should handle creation failure',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.createSquad(any)).thenAnswer((_) async => Left(ServerFailure('Creation failed')));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.createSquad(testSquad),
        expect: () => [
          const AsyncValue.loading(),
          predicate<AsyncValue<Squad>>((value) => value.hasError),
        ],
      );
    });

    group('loadSquad', () {
      testNotifier(
        'should load squad successfully',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.getSquad('squad123')).thenAnswer((_) async => Right(testSquad));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.loadSquad('squad123'),
        expect: () => [
          const AsyncValue.loading(),
          AsyncValue.data(testSquad),
        ],
      );

      testNotifier(
        'should handle load failure',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.getSquad('squad123')).thenAnswer((_) async => Left(ServerFailure('Load failed')));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.loadSquad('squad123'),
        expect: () => [
          const AsyncValue.loading(),
          predicate<AsyncValue<Squad>>((value) => value.hasError),
        ],
      );
    });

    group('loadUserSquads', () {
      testNotifier(
        'should load user squads successfully',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.getUserSquads('uid1')).thenAnswer((_) async => Right([testSquad]));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.loadUserSquads('uid1'),
        expect: () => [
          const AsyncValue.loading(),
          AsyncValue.data([testSquad]),
        ],
      );
    });

    group('updateSquad', () {
      testNotifier(
        'should update squad successfully',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.updateSquad(testSquad)).thenAnswer((_) async => const Right(unit));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.updateSquad(testSquad),
        expect: () => [
          const AsyncValue.loading(),
          AsyncValue.data(testSquad),
        ],
      );
    });

    group('joinSquad', () {
      testNotifier(
        'should join squad successfully',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.joinSquad('squad123', 'uid1')).thenAnswer((_) async => const Right(unit));
          when(mockRepository.getSquad('squad123')).thenAnswer((_) async => Right(testSquad));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.joinSquad('squad123', 'uid1'),
        expect: () => [
          const AsyncValue.loading(),
          AsyncValue.data(testSquad),
        ],
      );
    });

    group('leaveSquad', () {
      testNotifier(
        'should leave squad successfully',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.leaveSquad('squad123', 'uid1')).thenAnswer((_) async => const Right(unit));
          when(mockRepository.getSquad('squad123')).thenAnswer((_) async => Right(testSquad));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.leaveSquad('squad123', 'uid1'),
        expect: () => [
          const AsyncValue.loading(),
          AsyncValue.data(testSquad),
        ],
      );
    });

    group('assignSpot', () {
      testNotifier(
        'should assign spot successfully',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.assignSpot('squad123', 1, 'uid1')).thenAnswer((_) async => const Right(unit));
          when(mockRepository.getSquad('squad123')).thenAnswer((_) async => Right(testSquad));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.assignSpot('squad123', 1, 'uid1'),
        expect: () => [
          const AsyncValue.loading(),
          AsyncValue.data(testSquad),
        ],
      );
    });

    group('startSpotTimer', () {
      testNotifier(
        'should start timer successfully',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.startSpotTimer('squad123', 1, Duration(minutes: 5))).thenAnswer((_) async => const Right(unit));
          when(mockRepository.getSquad('squad123')).thenAnswer((_) async => Right(testSquad));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.startSpotTimer('squad123', 1, Duration(minutes: 5)),
        expect: () => [
          const AsyncValue.loading(),
          AsyncValue.data(testSquad),
        ],
      );
    });

    group('cancelSpotTimer', () {
      testNotifier(
        'should cancel timer successfully',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.cancelSpotTimer('squad123', 1)).thenAnswer((_) async => const Right(unit));
          when(mockRepository.getSquad('squad123')).thenAnswer((_) async => Right(testSquad));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.cancelSpotTimer('squad123', 1),
        expect: () => [
          const AsyncValue.loading(),
          AsyncValue.data(testSquad),
        ],
      );
    });

    group('deleteSquad', () {
      testNotifier(
        'should delete squad successfully',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.deleteSquad('squad123')).thenAnswer((_) async => const Right(unit));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.deleteSquad('squad123'),
        expect: () => [
          const AsyncValue.loading(),
          const AsyncValue.data(null),
        ],
      );
    });

    group('purgeOldData', () {
      testNotifier(
        'should purge old data successfully',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.purgeOldData()).thenAnswer((_) async => const Right(unit));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async => await notifier.purgeOldData(),
        expect: () => [
          const AsyncValue.loading(),
          const AsyncValue.data(null),
        ],
      );
    });

    group('clearError', () {
      testNotifier(
        'should clear error state',
        provider: squadNotifierProvider,
        setUp: () {
          when(mockRepository.getSquad('squad123')).thenAnswer((_) async => Left(ServerFailure('Error')));
        },
        builder: () => SquadNotifier(mockRepository),
        act: (notifier) async {
          await notifier.loadSquad('squad123'); // First trigger error
          notifier.clearError(); // Then clear it
        },
        expect: () => [
          const AsyncValue.loading(),
          predicate<AsyncValue<Squad>>((value) => value.hasError),
          const AsyncValue.data(null),
        ],
      );
    });
  });
}