import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/services/background_sync_service.dart';

/// State for connectivity tracking
class ConnectivityState {
  final bool isOnline;
  final DateTime? lastOnline;
  final int pendingItemsCount;

  const ConnectivityState({
    required this.isOnline,
    this.lastOnline,
    this.pendingItemsCount = 0,
  });

  ConnectivityState copyWith({
    bool? isOnline,
    DateTime? lastOnline,
    int? pendingItemsCount,
  }) {
    return ConnectivityState(
      isOnline: isOnline ?? this.isOnline,
      lastOnline: lastOnline ?? this.lastOnline,
      pendingItemsCount: pendingItemsCount ?? this.pendingItemsCount,
    );
  }
}

/// Notifier for managing connectivity state and offline-first operations
class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  late final BackgroundSyncService _syncService;

  ConnectivityNotifier() : super(const ConnectivityState(isOnline: true)) {
    _syncService = BackgroundSyncService();
    _initializeSync();
  }

  Future<void> _initializeSync() async {
    await _syncService.initialize();

    // Update state with current connectivity
    state = state.copyWith(
      isOnline: _syncService.isCurrentlyOnline,
    );
  }

  /// Check if device is currently online
  Future<bool> checkConnectivity() async {
    final isOnline = await _syncService.isOnline();
    state = state.copyWith(
      isOnline: isOnline,
      lastOnline: isOnline ? DateTime.now() : state.lastOnline,
    );
    return isOnline;
  }

  /// Trigger immediate sync when back online
  Future<void> triggerSync() async {
    if (state.isOnline) {
      await _syncService.triggerImmediateSync();
    }
  }

  /// Update pending items count
  void updatePendingCount(int count) {
    state = state.copyWith(pendingItemsCount: count);
  }

  /// Get current online status (cached)
  bool get isOnline => state.isOnline;
}

/// Provider for ConnectivityNotifier
final connectivityNotifierProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>(
  (ref) => ConnectivityNotifier(),
);
