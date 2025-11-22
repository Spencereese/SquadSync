// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$squadSpotsHash() => r'9942f5b2bd2e38a488c3943b58ddb2be20f28362';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [squadSpots].
@ProviderFor(squadSpots)
const squadSpotsProvider = SquadSpotsFamily();

/// See also [squadSpots].
class SquadSpotsFamily extends Family<List<String?>> {
  /// See also [squadSpots].
  const SquadSpotsFamily();

  /// See also [squadSpots].
  SquadSpotsProvider call(
    String gameName,
  ) {
    return SquadSpotsProvider(
      gameName,
    );
  }

  @override
  SquadSpotsProvider getProviderOverride(
    covariant SquadSpotsProvider provider,
  ) {
    return call(
      provider.gameName,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'squadSpotsProvider';
}

/// See also [squadSpots].
class SquadSpotsProvider extends AutoDisposeProvider<List<String?>> {
  /// See also [squadSpots].
  SquadSpotsProvider(
    String gameName,
  ) : this._internal(
          (ref) => squadSpots(
            ref as SquadSpotsRef,
            gameName,
          ),
          from: squadSpotsProvider,
          name: r'squadSpotsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$squadSpotsHash,
          dependencies: SquadSpotsFamily._dependencies,
          allTransitiveDependencies:
              SquadSpotsFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  SquadSpotsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameName,
  }) : super.internal();

  final String gameName;

  @override
  Override overrideWith(
    List<String?> Function(SquadSpotsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SquadSpotsProvider._internal(
        (ref) => create(ref as SquadSpotsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameName: gameName,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<String?>> createElement() {
    return _SquadSpotsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SquadSpotsProvider && other.gameName == gameName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameName.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SquadSpotsRef on AutoDisposeProviderRef<List<String?>> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _SquadSpotsProviderElement
    extends AutoDisposeProviderElement<List<String?>> with SquadSpotsRef {
  _SquadSpotsProviderElement(super.provider);

  @override
  String get gameName => (origin as SquadSpotsProvider).gameName;
}

String _$spotTimersHash() => r'fd6c96e62265c1d027de64d9f926b0929323eb9f';

/// See also [spotTimers].
@ProviderFor(spotTimers)
const spotTimersProvider = SpotTimersFamily();

/// See also [spotTimers].
class SpotTimersFamily extends Family<List<Map<String, dynamic>?>> {
  /// See also [spotTimers].
  const SpotTimersFamily();

  /// See also [spotTimers].
  SpotTimersProvider call(
    String gameName,
  ) {
    return SpotTimersProvider(
      gameName,
    );
  }

  @override
  SpotTimersProvider getProviderOverride(
    covariant SpotTimersProvider provider,
  ) {
    return call(
      provider.gameName,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'spotTimersProvider';
}

/// See also [spotTimers].
class SpotTimersProvider
    extends AutoDisposeProvider<List<Map<String, dynamic>?>> {
  /// See also [spotTimers].
  SpotTimersProvider(
    String gameName,
  ) : this._internal(
          (ref) => spotTimers(
            ref as SpotTimersRef,
            gameName,
          ),
          from: spotTimersProvider,
          name: r'spotTimersProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$spotTimersHash,
          dependencies: SpotTimersFamily._dependencies,
          allTransitiveDependencies:
              SpotTimersFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  SpotTimersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameName,
  }) : super.internal();

  final String gameName;

  @override
  Override overrideWith(
    List<Map<String, dynamic>?> Function(SpotTimersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SpotTimersProvider._internal(
        (ref) => create(ref as SpotTimersRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameName: gameName,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<Map<String, dynamic>?>> createElement() {
    return _SpotTimersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SpotTimersProvider && other.gameName == gameName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameName.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SpotTimersRef on AutoDisposeProviderRef<List<Map<String, dynamic>?>> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _SpotTimersProviderElement
    extends AutoDisposeProviderElement<List<Map<String, dynamic>?>>
    with SpotTimersRef {
  _SpotTimersProviderElement(super.provider);

  @override
  String get gameName => (origin as SpotTimersProvider).gameName;
}

String _$gameStatusesHash() => r'bf6f27267c9bb4e122d7e13fbc8ce7c9c167bbda';

/// See also [gameStatuses].
@ProviderFor(gameStatuses)
const gameStatusesProvider = GameStatusesFamily();

/// See also [gameStatuses].
class GameStatusesFamily extends Family<Map<String, String>> {
  /// See also [gameStatuses].
  const GameStatusesFamily();

  /// See also [gameStatuses].
  GameStatusesProvider call(
    String gameName,
  ) {
    return GameStatusesProvider(
      gameName,
    );
  }

  @override
  GameStatusesProvider getProviderOverride(
    covariant GameStatusesProvider provider,
  ) {
    return call(
      provider.gameName,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'gameStatusesProvider';
}

/// See also [gameStatuses].
class GameStatusesProvider extends AutoDisposeProvider<Map<String, String>> {
  /// See also [gameStatuses].
  GameStatusesProvider(
    String gameName,
  ) : this._internal(
          (ref) => gameStatuses(
            ref as GameStatusesRef,
            gameName,
          ),
          from: gameStatusesProvider,
          name: r'gameStatusesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameStatusesHash,
          dependencies: GameStatusesFamily._dependencies,
          allTransitiveDependencies:
              GameStatusesFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  GameStatusesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameName,
  }) : super.internal();

  final String gameName;

  @override
  Override overrideWith(
    Map<String, String> Function(GameStatusesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GameStatusesProvider._internal(
        (ref) => create(ref as GameStatusesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameName: gameName,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<Map<String, String>> createElement() {
    return _GameStatusesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameStatusesProvider && other.gameName == gameName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameName.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GameStatusesRef on AutoDisposeProviderRef<Map<String, String>> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _GameStatusesProviderElement
    extends AutoDisposeProviderElement<Map<String, String>>
    with GameStatusesRef {
  _GameStatusesProviderElement(super.provider);

  @override
  String get gameName => (origin as GameStatusesProvider).gameName;
}

String _$spotTimerStateHash() => r'17a3a194a26a74737440a56cb11d6fcbe1c98132';

/// See also [spotTimerState].
@ProviderFor(spotTimerState)
const spotTimerStateProvider = SpotTimerStateFamily();

/// See also [spotTimerState].
class SpotTimerStateFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// See also [spotTimerState].
  const SpotTimerStateFamily();

  /// See also [spotTimerState].
  SpotTimerStateProvider call(
    String gameName,
    int spotIndex,
  ) {
    return SpotTimerStateProvider(
      gameName,
      spotIndex,
    );
  }

  @override
  SpotTimerStateProvider getProviderOverride(
    covariant SpotTimerStateProvider provider,
  ) {
    return call(
      provider.gameName,
      provider.spotIndex,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'spotTimerStateProvider';
}

/// See also [spotTimerState].
class SpotTimerStateProvider
    extends AutoDisposeProvider<AsyncValue<Map<String, dynamic>>> {
  /// See also [spotTimerState].
  SpotTimerStateProvider(
    String gameName,
    int spotIndex,
  ) : this._internal(
          (ref) => spotTimerState(
            ref as SpotTimerStateRef,
            gameName,
            spotIndex,
          ),
          from: spotTimerStateProvider,
          name: r'spotTimerStateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$spotTimerStateHash,
          dependencies: SpotTimerStateFamily._dependencies,
          allTransitiveDependencies:
              SpotTimerStateFamily._allTransitiveDependencies,
          gameName: gameName,
          spotIndex: spotIndex,
        );

  SpotTimerStateProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameName,
    required this.spotIndex,
  }) : super.internal();

  final String gameName;
  final int spotIndex;

  @override
  Override overrideWith(
    AsyncValue<Map<String, dynamic>> Function(SpotTimerStateRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SpotTimerStateProvider._internal(
        (ref) => create(ref as SpotTimerStateRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameName: gameName,
        spotIndex: spotIndex,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<AsyncValue<Map<String, dynamic>>> createElement() {
    return _SpotTimerStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SpotTimerStateProvider &&
        other.gameName == gameName &&
        other.spotIndex == spotIndex;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameName.hashCode);
    hash = _SystemHash.combine(hash, spotIndex.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SpotTimerStateRef
    on AutoDisposeProviderRef<AsyncValue<Map<String, dynamic>>> {
  /// The parameter `gameName` of this provider.
  String get gameName;

  /// The parameter `spotIndex` of this provider.
  int get spotIndex;
}

class _SpotTimerStateProviderElement
    extends AutoDisposeProviderElement<AsyncValue<Map<String, dynamic>>>
    with SpotTimerStateRef {
  _SpotTimerStateProviderElement(super.provider);

  @override
  String get gameName => (origin as SpotTimerStateProvider).gameName;
  @override
  int get spotIndex => (origin as SpotTimerStateProvider).spotIndex;
}

String _$peacockTimerStateHash() => r'ff19a1d7ed039af7b2691d019a918fd698250502';

/// See also [peacockTimerState].
@ProviderFor(peacockTimerState)
const peacockTimerStateProvider = PeacockTimerStateFamily();

/// See also [peacockTimerState].
class PeacockTimerStateFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// See also [peacockTimerState].
  const PeacockTimerStateFamily();

  /// See also [peacockTimerState].
  PeacockTimerStateProvider call(
    String userId,
  ) {
    return PeacockTimerStateProvider(
      userId,
    );
  }

  @override
  PeacockTimerStateProvider getProviderOverride(
    covariant PeacockTimerStateProvider provider,
  ) {
    return call(
      provider.userId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'peacockTimerStateProvider';
}

/// See also [peacockTimerState].
class PeacockTimerStateProvider
    extends AutoDisposeProvider<AsyncValue<Map<String, dynamic>>> {
  /// See also [peacockTimerState].
  PeacockTimerStateProvider(
    String userId,
  ) : this._internal(
          (ref) => peacockTimerState(
            ref as PeacockTimerStateRef,
            userId,
          ),
          from: peacockTimerStateProvider,
          name: r'peacockTimerStateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$peacockTimerStateHash,
          dependencies: PeacockTimerStateFamily._dependencies,
          allTransitiveDependencies:
              PeacockTimerStateFamily._allTransitiveDependencies,
          userId: userId,
        );

  PeacockTimerStateProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    AsyncValue<Map<String, dynamic>> Function(PeacockTimerStateRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PeacockTimerStateProvider._internal(
        (ref) => create(ref as PeacockTimerStateRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<AsyncValue<Map<String, dynamic>>> createElement() {
    return _PeacockTimerStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PeacockTimerStateProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PeacockTimerStateRef
    on AutoDisposeProviderRef<AsyncValue<Map<String, dynamic>>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _PeacockTimerStateProviderElement
    extends AutoDisposeProviderElement<AsyncValue<Map<String, dynamic>>>
    with PeacockTimerStateRef {
  _PeacockTimerStateProviderElement(super.provider);

  @override
  String get userId => (origin as PeacockTimerStateProvider).userId;
}

String _$spotTimerStreamHash() => r'e4fbfc831857a79923ca6eb0b38ea5546f5c1bd7';

/// See also [spotTimerStream].
@ProviderFor(spotTimerStream)
const spotTimerStreamProvider = SpotTimerStreamFamily();

/// See also [spotTimerStream].
class SpotTimerStreamFamily extends Family<AsyncValue<Duration>> {
  /// See also [spotTimerStream].
  const SpotTimerStreamFamily();

  /// See also [spotTimerStream].
  SpotTimerStreamProvider call(
    String gameName,
    int spotIndex,
  ) {
    return SpotTimerStreamProvider(
      gameName,
      spotIndex,
    );
  }

  @override
  SpotTimerStreamProvider getProviderOverride(
    covariant SpotTimerStreamProvider provider,
  ) {
    return call(
      provider.gameName,
      provider.spotIndex,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'spotTimerStreamProvider';
}

/// See also [spotTimerStream].
class SpotTimerStreamProvider extends AutoDisposeStreamProvider<Duration> {
  /// See also [spotTimerStream].
  SpotTimerStreamProvider(
    String gameName,
    int spotIndex,
  ) : this._internal(
          (ref) => spotTimerStream(
            ref as SpotTimerStreamRef,
            gameName,
            spotIndex,
          ),
          from: spotTimerStreamProvider,
          name: r'spotTimerStreamProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$spotTimerStreamHash,
          dependencies: SpotTimerStreamFamily._dependencies,
          allTransitiveDependencies:
              SpotTimerStreamFamily._allTransitiveDependencies,
          gameName: gameName,
          spotIndex: spotIndex,
        );

  SpotTimerStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameName,
    required this.spotIndex,
  }) : super.internal();

  final String gameName;
  final int spotIndex;

  @override
  Override overrideWith(
    Stream<Duration> Function(SpotTimerStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SpotTimerStreamProvider._internal(
        (ref) => create(ref as SpotTimerStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameName: gameName,
        spotIndex: spotIndex,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<Duration> createElement() {
    return _SpotTimerStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SpotTimerStreamProvider &&
        other.gameName == gameName &&
        other.spotIndex == spotIndex;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameName.hashCode);
    hash = _SystemHash.combine(hash, spotIndex.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SpotTimerStreamRef on AutoDisposeStreamProviderRef<Duration> {
  /// The parameter `gameName` of this provider.
  String get gameName;

  /// The parameter `spotIndex` of this provider.
  int get spotIndex;
}

class _SpotTimerStreamProviderElement
    extends AutoDisposeStreamProviderElement<Duration> with SpotTimerStreamRef {
  _SpotTimerStreamProviderElement(super.provider);

  @override
  String get gameName => (origin as SpotTimerStreamProvider).gameName;
  @override
  int get spotIndex => (origin as SpotTimerStreamProvider).spotIndex;
}

String _$peacockTimerStreamHash() =>
    r'a797d0dcca6de0059fe5dc0506dccb4ba2784118';

/// See also [peacockTimerStream].
@ProviderFor(peacockTimerStream)
const peacockTimerStreamProvider = PeacockTimerStreamFamily();

/// See also [peacockTimerStream].
class PeacockTimerStreamFamily extends Family<AsyncValue<Duration>> {
  /// See also [peacockTimerStream].
  const PeacockTimerStreamFamily();

  /// See also [peacockTimerStream].
  PeacockTimerStreamProvider call(
    String userId,
  ) {
    return PeacockTimerStreamProvider(
      userId,
    );
  }

  @override
  PeacockTimerStreamProvider getProviderOverride(
    covariant PeacockTimerStreamProvider provider,
  ) {
    return call(
      provider.userId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'peacockTimerStreamProvider';
}

/// See also [peacockTimerStream].
class PeacockTimerStreamProvider extends AutoDisposeStreamProvider<Duration> {
  /// See also [peacockTimerStream].
  PeacockTimerStreamProvider(
    String userId,
  ) : this._internal(
          (ref) => peacockTimerStream(
            ref as PeacockTimerStreamRef,
            userId,
          ),
          from: peacockTimerStreamProvider,
          name: r'peacockTimerStreamProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$peacockTimerStreamHash,
          dependencies: PeacockTimerStreamFamily._dependencies,
          allTransitiveDependencies:
              PeacockTimerStreamFamily._allTransitiveDependencies,
          userId: userId,
        );

  PeacockTimerStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    Stream<Duration> Function(PeacockTimerStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PeacockTimerStreamProvider._internal(
        (ref) => create(ref as PeacockTimerStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<Duration> createElement() {
    return _PeacockTimerStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PeacockTimerStreamProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PeacockTimerStreamRef on AutoDisposeStreamProviderRef<Duration> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _PeacockTimerStreamProviderElement
    extends AutoDisposeStreamProviderElement<Duration>
    with PeacockTimerStreamRef {
  _PeacockTimerStreamProviderElement(super.provider);

  @override
  String get userId => (origin as PeacockTimerStreamProvider).userId;
}

String _$squadNotifierHash() => r'f35cadf46fdabc489dfa572b509e054b6c6e4017';

/// See also [SquadNotifier].
@ProviderFor(SquadNotifier)
final squadNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SquadNotifier, SquadState>.internal(
  SquadNotifier.new,
  name: r'squadNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$squadNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SquadNotifier = AutoDisposeAsyncNotifier<SquadState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
