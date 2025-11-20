// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generated_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userGreetingHash() => r'a9ef50e617eaef7b7506d77778504d7d27b0ea20';

/// Generated provider with dependencies
///
/// Copied from [userGreeting].
@ProviderFor(userGreeting)
final userGreetingProvider = AutoDisposeProvider<String>.internal(
  userGreeting,
  name: r'userGreetingProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userGreetingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserGreetingRef = AutoDisposeProviderRef<String>;
String _$userPinnedGamesHash() => r'c6d82580f8c45d165496f567e0195f64b140fd66';

/// Generated provider for async operations
///
/// Copied from [userPinnedGames].
@ProviderFor(userPinnedGames)
final userPinnedGamesProvider =
    AutoDisposeFutureProvider<List<String>>.internal(
  userPinnedGames,
  name: r'userPinnedGamesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userPinnedGamesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserPinnedGamesRef = AutoDisposeFutureProviderRef<List<String>>;
String _$gameStatusHash() => r'36067bac20b3c675b4e02822257dd534e6425049';

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

/// Generated provider with family (parameterized)
///
/// Copied from [gameStatus].
@ProviderFor(gameStatus)
const gameStatusProvider = GameStatusFamily();

/// Generated provider with family (parameterized)
///
/// Copied from [gameStatus].
class GameStatusFamily extends Family<String> {
  /// Generated provider with family (parameterized)
  ///
  /// Copied from [gameStatus].
  const GameStatusFamily();

  /// Generated provider with family (parameterized)
  ///
  /// Copied from [gameStatus].
  GameStatusProvider call(
    String gameName,
  ) {
    return GameStatusProvider(
      gameName,
    );
  }

  @override
  GameStatusProvider getProviderOverride(
    covariant GameStatusProvider provider,
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
  String? get name => r'gameStatusProvider';
}

/// Generated provider with family (parameterized)
///
/// Copied from [gameStatus].
class GameStatusProvider extends AutoDisposeProvider<String> {
  /// Generated provider with family (parameterized)
  ///
  /// Copied from [gameStatus].
  GameStatusProvider(
    String gameName,
  ) : this._internal(
          (ref) => gameStatus(
            ref as GameStatusRef,
            gameName,
          ),
          from: gameStatusProvider,
          name: r'gameStatusProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameStatusHash,
          dependencies: GameStatusFamily._dependencies,
          allTransitiveDependencies:
              GameStatusFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  GameStatusProvider._internal(
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
    String Function(GameStatusRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GameStatusProvider._internal(
        (ref) => create(ref as GameStatusRef),
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
  AutoDisposeProviderElement<String> createElement() {
    return _GameStatusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameStatusProvider && other.gameName == gameName;
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
mixin GameStatusRef on AutoDisposeProviderRef<String> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _GameStatusProviderElement extends AutoDisposeProviderElement<String>
    with GameStatusRef {
  _GameStatusProviderElement(super.provider);

  @override
  String get gameName => (origin as GameStatusProvider).gameName;
}

String _$userDisplayNameHash() => r'83750e67592fd088cd37c1b15754e85c7ba4422b';

/// Example of migrating existing providers to generated ones
/// This shows the pattern for converting manual providers to generated providers
///
/// Copied from [userDisplayName].
@ProviderFor(userDisplayName)
final userDisplayNameProvider = AutoDisposeProvider<String>.internal(
  userDisplayName,
  name: r'userDisplayNameProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userDisplayNameHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserDisplayNameRef = AutoDisposeProviderRef<String>;
String _$userStatsHash() => r'3b936c178880b047922c3c6838739ffcdee76660';

/// Example of a generated provider with complex logic
///
/// Copied from [userStats].
@ProviderFor(userStats)
final userStatsProvider = AutoDisposeProvider<Map<String, dynamic>>.internal(
  userStats,
  name: r'userStatsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserStatsRef = AutoDisposeProviderRef<Map<String, dynamic>>;
String _$counterHash() => r'4243b34530f53accfd9014a9f0e316fe304ada3e';

/// Example of Riverpod code generation for better performance
/// This file demonstrates how to use @riverpod annotations for automatic code generation
/// Generated provider - more efficient with code generation
///
/// Copied from [Counter].
@ProviderFor(Counter)
final counterProvider = AutoDisposeNotifierProvider<Counter, int>.internal(
  Counter.new,
  name: r'counterProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$counterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Counter = AutoDisposeNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
