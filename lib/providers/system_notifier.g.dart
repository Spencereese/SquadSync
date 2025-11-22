// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$systemNotifierHash() => r'2a8277374c41d2ccec56f463b99fac18c21c304f';

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

abstract class _$SystemNotifier
    extends BuildlessAutoDisposeAsyncNotifier<SystemState> {
  late final FirebaseAuth? auth;
  late final FirebaseFirestore? firestore;

  FutureOr<SystemState> build({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  });
}

/// See also [SystemNotifier].
@ProviderFor(SystemNotifier)
const systemNotifierProvider = SystemNotifierFamily();

/// See also [SystemNotifier].
class SystemNotifierFamily extends Family<AsyncValue<SystemState>> {
  /// See also [SystemNotifier].
  const SystemNotifierFamily();

  /// See also [SystemNotifier].
  SystemNotifierProvider call({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) {
    return SystemNotifierProvider(
      auth: auth,
      firestore: firestore,
    );
  }

  @override
  SystemNotifierProvider getProviderOverride(
    covariant SystemNotifierProvider provider,
  ) {
    return call(
      auth: provider.auth,
      firestore: provider.firestore,
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
  String? get name => r'systemNotifierProvider';
}

/// See also [SystemNotifier].
class SystemNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<SystemNotifier, SystemState> {
  /// See also [SystemNotifier].
  SystemNotifierProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : this._internal(
          () => SystemNotifier()
            ..auth = auth
            ..firestore = firestore,
          from: systemNotifierProvider,
          name: r'systemNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$systemNotifierHash,
          dependencies: SystemNotifierFamily._dependencies,
          allTransitiveDependencies:
              SystemNotifierFamily._allTransitiveDependencies,
          auth: auth,
          firestore: firestore,
        );

  SystemNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.auth,
    required this.firestore,
  }) : super.internal();

  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  @override
  FutureOr<SystemState> runNotifierBuild(
    covariant SystemNotifier notifier,
  ) {
    return notifier.build(
      auth: auth,
      firestore: firestore,
    );
  }

  @override
  Override overrideWith(SystemNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: SystemNotifierProvider._internal(
        () => create()
          ..auth = auth
          ..firestore = firestore,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        auth: auth,
        firestore: firestore,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<SystemNotifier, SystemState>
      createElement() {
    return _SystemNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SystemNotifierProvider &&
        other.auth == auth &&
        other.firestore == firestore;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, auth.hashCode);
    hash = _SystemHash.combine(hash, firestore.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SystemNotifierRef on AutoDisposeAsyncNotifierProviderRef<SystemState> {
  /// The parameter `auth` of this provider.
  FirebaseAuth? get auth;

  /// The parameter `firestore` of this provider.
  FirebaseFirestore? get firestore;
}

class _SystemNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<SystemNotifier, SystemState>
    with SystemNotifierRef {
  _SystemNotifierProviderElement(super.provider);

  @override
  FirebaseAuth? get auth => (origin as SystemNotifierProvider).auth;
  @override
  FirebaseFirestore? get firestore =>
      (origin as SystemNotifierProvider).firestore;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
