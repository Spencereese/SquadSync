// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gameSearchResultsHash() => r'946bc1de841f08d4251f3c06e099bbdaf9c43ba7';

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

/// Family provider for query-based game searches
///
/// Copied from [gameSearchResults].
@ProviderFor(gameSearchResults)
const gameSearchResultsProvider = GameSearchResultsFamily();

/// Family provider for query-based game searches
///
/// Copied from [gameSearchResults].
class GameSearchResultsFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// Family provider for query-based game searches
  ///
  /// Copied from [gameSearchResults].
  const GameSearchResultsFamily();

  /// Family provider for query-based game searches
  ///
  /// Copied from [gameSearchResults].
  GameSearchResultsProvider call(
    String query,
  ) {
    return GameSearchResultsProvider(
      query,
    );
  }

  @override
  GameSearchResultsProvider getProviderOverride(
    covariant GameSearchResultsProvider provider,
  ) {
    return call(
      provider.query,
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
  String? get name => r'gameSearchResultsProvider';
}

/// Family provider for query-based game searches
///
/// Copied from [gameSearchResults].
class GameSearchResultsProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// Family provider for query-based game searches
  ///
  /// Copied from [gameSearchResults].
  GameSearchResultsProvider(
    String query,
  ) : this._internal(
          (ref) => gameSearchResults(
            ref as GameSearchResultsRef,
            query,
          ),
          from: gameSearchResultsProvider,
          name: r'gameSearchResultsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameSearchResultsHash,
          dependencies: GameSearchResultsFamily._dependencies,
          allTransitiveDependencies:
              GameSearchResultsFamily._allTransitiveDependencies,
          query: query,
        );

  GameSearchResultsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
  }) : super.internal();

  final String query;

  @override
  Override overrideWith(
    FutureOr<List<Map<String, dynamic>>> Function(GameSearchResultsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GameSearchResultsProvider._internal(
        (ref) => create(ref as GameSearchResultsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _GameSearchResultsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameSearchResultsProvider && other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GameSearchResultsRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `query` of this provider.
  String get query;
}

class _GameSearchResultsProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with GameSearchResultsRef {
  _GameSearchResultsProviderElement(super.provider);

  @override
  String get query => (origin as GameSearchResultsProvider).query;
}

String _$gameDetailsHash() => r'e58b998b37d8e0329380e5dea1e4be6485987d54';

/// Family provider for game details with caching
///
/// Copied from [gameDetails].
@ProviderFor(gameDetails)
const gameDetailsProvider = GameDetailsFamily();

/// Family provider for game details with caching
///
/// Copied from [gameDetails].
class GameDetailsFamily extends Family<AsyncValue<Map<String, dynamic>?>> {
  /// Family provider for game details with caching
  ///
  /// Copied from [gameDetails].
  const GameDetailsFamily();

  /// Family provider for game details with caching
  ///
  /// Copied from [gameDetails].
  GameDetailsProvider call(
    String gameSlug,
  ) {
    return GameDetailsProvider(
      gameSlug,
    );
  }

  @override
  GameDetailsProvider getProviderOverride(
    covariant GameDetailsProvider provider,
  ) {
    return call(
      provider.gameSlug,
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
  String? get name => r'gameDetailsProvider';
}

/// Family provider for game details with caching
///
/// Copied from [gameDetails].
class GameDetailsProvider
    extends AutoDisposeFutureProvider<Map<String, dynamic>?> {
  /// Family provider for game details with caching
  ///
  /// Copied from [gameDetails].
  GameDetailsProvider(
    String gameSlug,
  ) : this._internal(
          (ref) => gameDetails(
            ref as GameDetailsRef,
            gameSlug,
          ),
          from: gameDetailsProvider,
          name: r'gameDetailsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameDetailsHash,
          dependencies: GameDetailsFamily._dependencies,
          allTransitiveDependencies:
              GameDetailsFamily._allTransitiveDependencies,
          gameSlug: gameSlug,
        );

  GameDetailsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameSlug,
  }) : super.internal();

  final String gameSlug;

  @override
  Override overrideWith(
    FutureOr<Map<String, dynamic>?> Function(GameDetailsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GameDetailsProvider._internal(
        (ref) => create(ref as GameDetailsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameSlug: gameSlug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Map<String, dynamic>?> createElement() {
    return _GameDetailsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameDetailsProvider && other.gameSlug == gameSlug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameSlug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GameDetailsRef on AutoDisposeFutureProviderRef<Map<String, dynamic>?> {
  /// The parameter `gameSlug` of this provider.
  String get gameSlug;
}

class _GameDetailsProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, dynamic>?>
    with GameDetailsRef {
  _GameDetailsProviderElement(super.provider);

  @override
  String get gameSlug => (origin as GameDetailsProvider).gameSlug;
}

String _$popularGamesHash() => r'2e517a1deefc3c9b06700cb5e4b9ed82c33e8ac2';

/// Family provider for popular games (empty query)
///
/// Copied from [popularGames].
@ProviderFor(popularGames)
final popularGamesProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
  popularGames,
  name: r'popularGamesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$popularGamesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PopularGamesRef
    = AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$gameScopedDataHash() => r'2065f42e1f55c46c5640c9f126d5e331b2fb2f17';

/// Provider for game-scoped data with current game context
///
/// Copied from [gameScopedData].
@ProviderFor(gameScopedData)
const gameScopedDataProvider = GameScopedDataFamily();

/// Provider for game-scoped data with current game context
///
/// Copied from [gameScopedData].
class GameScopedDataFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// Provider for game-scoped data with current game context
  ///
  /// Copied from [gameScopedData].
  const GameScopedDataFamily();

  /// Provider for game-scoped data with current game context
  ///
  /// Copied from [gameScopedData].
  GameScopedDataProvider call(
    String gameName,
  ) {
    return GameScopedDataProvider(
      gameName,
    );
  }

  @override
  GameScopedDataProvider getProviderOverride(
    covariant GameScopedDataProvider provider,
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
  String? get name => r'gameScopedDataProvider';
}

/// Provider for game-scoped data with current game context
///
/// Copied from [gameScopedData].
class GameScopedDataProvider
    extends AutoDisposeFutureProvider<Map<String, dynamic>> {
  /// Provider for game-scoped data with current game context
  ///
  /// Copied from [gameScopedData].
  GameScopedDataProvider(
    String gameName,
  ) : this._internal(
          (ref) => gameScopedData(
            ref as GameScopedDataRef,
            gameName,
          ),
          from: gameScopedDataProvider,
          name: r'gameScopedDataProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameScopedDataHash,
          dependencies: GameScopedDataFamily._dependencies,
          allTransitiveDependencies:
              GameScopedDataFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  GameScopedDataProvider._internal(
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
    FutureOr<Map<String, dynamic>> Function(GameScopedDataRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GameScopedDataProvider._internal(
        (ref) => create(ref as GameScopedDataRef),
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
  AutoDisposeFutureProviderElement<Map<String, dynamic>> createElement() {
    return _GameScopedDataProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameScopedDataProvider && other.gameName == gameName;
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
mixin GameScopedDataRef on AutoDisposeFutureProviderRef<Map<String, dynamic>> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _GameScopedDataProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, dynamic>>
    with GameScopedDataRef {
  _GameScopedDataProviderElement(super.provider);

  @override
  String get gameName => (origin as GameScopedDataProvider).gameName;
}

String _$userGamePreferencesHash() =>
    r'8169d17d95973f7a498827748e77e8393c6ee797';

/// Provider for UID-based user game preferences
///
/// Copied from [userGamePreferences].
@ProviderFor(userGamePreferences)
const userGamePreferencesProvider = UserGamePreferencesFamily();

/// Provider for UID-based user game preferences
///
/// Copied from [userGamePreferences].
class UserGamePreferencesFamily
    extends Family<AsyncValue<Map<String, dynamic>>> {
  /// Provider for UID-based user game preferences
  ///
  /// Copied from [userGamePreferences].
  const UserGamePreferencesFamily();

  /// Provider for UID-based user game preferences
  ///
  /// Copied from [userGamePreferences].
  UserGamePreferencesProvider call(
    String userId,
  ) {
    return UserGamePreferencesProvider(
      userId,
    );
  }

  @override
  UserGamePreferencesProvider getProviderOverride(
    covariant UserGamePreferencesProvider provider,
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
  String? get name => r'userGamePreferencesProvider';
}

/// Provider for UID-based user game preferences
///
/// Copied from [userGamePreferences].
class UserGamePreferencesProvider
    extends AutoDisposeFutureProvider<Map<String, dynamic>> {
  /// Provider for UID-based user game preferences
  ///
  /// Copied from [userGamePreferences].
  UserGamePreferencesProvider(
    String userId,
  ) : this._internal(
          (ref) => userGamePreferences(
            ref as UserGamePreferencesRef,
            userId,
          ),
          from: userGamePreferencesProvider,
          name: r'userGamePreferencesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$userGamePreferencesHash,
          dependencies: UserGamePreferencesFamily._dependencies,
          allTransitiveDependencies:
              UserGamePreferencesFamily._allTransitiveDependencies,
          userId: userId,
        );

  UserGamePreferencesProvider._internal(
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
    FutureOr<Map<String, dynamic>> Function(UserGamePreferencesRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserGamePreferencesProvider._internal(
        (ref) => create(ref as UserGamePreferencesRef),
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
  AutoDisposeFutureProviderElement<Map<String, dynamic>> createElement() {
    return _UserGamePreferencesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserGamePreferencesProvider && other.userId == userId;
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
mixin UserGamePreferencesRef
    on AutoDisposeFutureProviderRef<Map<String, dynamic>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserGamePreferencesProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, dynamic>>
    with UserGamePreferencesRef {
  _UserGamePreferencesProviderElement(super.provider);

  @override
  String get userId => (origin as UserGamePreferencesProvider).userId;
}

String _$gameStatisticsHash() => r'8a120843f6663df9c7cecf7edfef227412732f8b';

/// Provider for game statistics and analytics
///
/// Copied from [gameStatistics].
@ProviderFor(gameStatistics)
const gameStatisticsProvider = GameStatisticsFamily();

/// Provider for game statistics and analytics
///
/// Copied from [gameStatistics].
class GameStatisticsFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// Provider for game statistics and analytics
  ///
  /// Copied from [gameStatistics].
  const GameStatisticsFamily();

  /// Provider for game statistics and analytics
  ///
  /// Copied from [gameStatistics].
  GameStatisticsProvider call(
    String gameName,
  ) {
    return GameStatisticsProvider(
      gameName,
    );
  }

  @override
  GameStatisticsProvider getProviderOverride(
    covariant GameStatisticsProvider provider,
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
  String? get name => r'gameStatisticsProvider';
}

/// Provider for game statistics and analytics
///
/// Copied from [gameStatistics].
class GameStatisticsProvider
    extends AutoDisposeFutureProvider<Map<String, dynamic>> {
  /// Provider for game statistics and analytics
  ///
  /// Copied from [gameStatistics].
  GameStatisticsProvider(
    String gameName,
  ) : this._internal(
          (ref) => gameStatistics(
            ref as GameStatisticsRef,
            gameName,
          ),
          from: gameStatisticsProvider,
          name: r'gameStatisticsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameStatisticsHash,
          dependencies: GameStatisticsFamily._dependencies,
          allTransitiveDependencies:
              GameStatisticsFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  GameStatisticsProvider._internal(
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
    FutureOr<Map<String, dynamic>> Function(GameStatisticsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GameStatisticsProvider._internal(
        (ref) => create(ref as GameStatisticsRef),
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
  AutoDisposeFutureProviderElement<Map<String, dynamic>> createElement() {
    return _GameStatisticsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameStatisticsProvider && other.gameName == gameName;
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
mixin GameStatisticsRef on AutoDisposeFutureProviderRef<Map<String, dynamic>> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _GameStatisticsProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, dynamic>>
    with GameStatisticsRef {
  _GameStatisticsProviderElement(super.provider);

  @override
  String get gameName => (origin as GameStatisticsProvider).gameName;
}

String _$gameNotifierHash() => r'8e0d4fd4727280ec4d881e9b543a473f8acddb83';

abstract class _$GameNotifier
    extends BuildlessAutoDisposeAsyncNotifier<GameState> {
  late final FirebaseFirestore? firestore;
  late final FirebaseAuth? auth;
  late final IgdbAuthService? igdbAuthService;

  FutureOr<GameState> build({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    IgdbAuthService? igdbAuthService,
  });
}

/// See also [GameNotifier].
@ProviderFor(GameNotifier)
const gameNotifierProvider = GameNotifierFamily();

/// See also [GameNotifier].
class GameNotifierFamily extends Family<AsyncValue<GameState>> {
  /// See also [GameNotifier].
  const GameNotifierFamily();

  /// See also [GameNotifier].
  GameNotifierProvider call({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    IgdbAuthService? igdbAuthService,
  }) {
    return GameNotifierProvider(
      firestore: firestore,
      auth: auth,
      igdbAuthService: igdbAuthService,
    );
  }

  @override
  GameNotifierProvider getProviderOverride(
    covariant GameNotifierProvider provider,
  ) {
    return call(
      firestore: provider.firestore,
      auth: provider.auth,
      igdbAuthService: provider.igdbAuthService,
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
  String? get name => r'gameNotifierProvider';
}

/// See also [GameNotifier].
class GameNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<GameNotifier, GameState> {
  /// See also [GameNotifier].
  GameNotifierProvider({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    IgdbAuthService? igdbAuthService,
  }) : this._internal(
          () => GameNotifier()
            ..firestore = firestore
            ..auth = auth
            ..igdbAuthService = igdbAuthService,
          from: gameNotifierProvider,
          name: r'gameNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameNotifierHash,
          dependencies: GameNotifierFamily._dependencies,
          allTransitiveDependencies:
              GameNotifierFamily._allTransitiveDependencies,
          firestore: firestore,
          auth: auth,
          igdbAuthService: igdbAuthService,
        );

  GameNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.firestore,
    required this.auth,
    required this.igdbAuthService,
  }) : super.internal();

  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final IgdbAuthService? igdbAuthService;

  @override
  FutureOr<GameState> runNotifierBuild(
    covariant GameNotifier notifier,
  ) {
    return notifier.build(
      firestore: firestore,
      auth: auth,
      igdbAuthService: igdbAuthService,
    );
  }

  @override
  Override overrideWith(GameNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: GameNotifierProvider._internal(
        () => create()
          ..firestore = firestore
          ..auth = auth
          ..igdbAuthService = igdbAuthService,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        firestore: firestore,
        auth: auth,
        igdbAuthService: igdbAuthService,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<GameNotifier, GameState>
      createElement() {
    return _GameNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameNotifierProvider &&
        other.firestore == firestore &&
        other.auth == auth &&
        other.igdbAuthService == igdbAuthService;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, firestore.hashCode);
    hash = _SystemHash.combine(hash, auth.hashCode);
    hash = _SystemHash.combine(hash, igdbAuthService.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GameNotifierRef on AutoDisposeAsyncNotifierProviderRef<GameState> {
  /// The parameter `firestore` of this provider.
  FirebaseFirestore? get firestore;

  /// The parameter `auth` of this provider.
  FirebaseAuth? get auth;

  /// The parameter `igdbAuthService` of this provider.
  IgdbAuthService? get igdbAuthService;
}

class _GameNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<GameNotifier, GameState>
    with GameNotifierRef {
  _GameNotifierProviderElement(super.provider);

  @override
  FirebaseFirestore? get firestore =>
      (origin as GameNotifierProvider).firestore;
  @override
  FirebaseAuth? get auth => (origin as GameNotifierProvider).auth;
  @override
  IgdbAuthService? get igdbAuthService =>
      (origin as GameNotifierProvider).igdbAuthService;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
