import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import '../../chat/models/message_data.dart';

/// State for clips feed
class ClipState {
  final List<MessageData> clips;
  final bool hasMore;
  final bool isLoading;
  final String? error;
  final MessageData? clipOfTheDay;

  const ClipState({
    required this.clips,
    this.hasMore = true,
    this.isLoading = false,
    this.error,
    this.clipOfTheDay,
  });

  ClipState copyWith({
    List<MessageData>? clips,
    bool? hasMore,
    bool? isLoading,
    String? error,
    MessageData? clipOfTheDay,
  }) {
    return ClipState(
      clips: clips ?? this.clips,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      clipOfTheDay: clipOfTheDay ?? this.clipOfTheDay,
    );
  }

  factory ClipState.initial() {
    return const ClipState(
      clips: [],
      hasMore: true,
      isLoading: false,
    );
  }
}

/// Notifier for managing clips feed
class ClipNotifier extends AutoDisposeAsyncNotifier<ClipState> {
  StreamSubscription<List<Map<String, dynamic>>>? _clipsSubscription;
  String? _currentSquadId;
  int _currentOffset = 0;
  static const int _pageSize = 10;

  @override
  Future<ClipState> build() async {
    ref.onDispose(() {
      _clipsSubscription?.cancel();
    });
    return ClipState.initial();
  }

  /// Initialize real-time clips stream for a squad
  Future<void> initializeClipsStream(String squadId) async {
    if (_currentSquadId == squadId && _clipsSubscription != null) {
      return; // Already initialized for this squad
    }

    // Cancel existing subscription
    await _clipsSubscription?.cancel();
    _currentSquadId = squadId;
    _currentOffset = 0;

    // Load initial clips
    await _loadInitialClips(squadId);

    // Start real-time stream
    _startClipsStream(squadId);
  }

  Future<void> _loadInitialClips(String squadId) async {
    state = AsyncData(
        state.value?.copyWith(isLoading: true) ?? ClipState.initial());

    try {
      final data = await SupabaseService.client
          .from('clips')
          .select()
          .eq('squad_id', squadId)
          .order('created_at', ascending: false)
          .limit(_pageSize);

      final clips = data
          .map((json) => MessageData.fromMap(json))
          .where((msg) => msg.type == MessageType.clip)
          .whereType<MessageData>()
          .toList();

      _currentOffset = clips.length;

      // Load clip of the day
      final clipOfTheDay = await _loadClipOfTheDay(squadId);

      state = AsyncData(ClipState(
        clips: clips,
        hasMore: data.length >= _pageSize,
        isLoading: false,
        clipOfTheDay: clipOfTheDay,
      ));
    } catch (e) {
      debugPrint('Error loading initial clips: $e');
      state = AsyncData(ClipState.initial().copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  void _startClipsStream(String squadId) {
    final stream = SupabaseService.client
        .from('clips')
        .stream(primaryKey: ['id'])
        .eq('squad_id', squadId)
        .order('created_at', ascending: false)
        .limit(_pageSize);

    _clipsSubscription = stream.listen(
      (data) {
        if (data.isEmpty) return;

        final clips = data
            .map((json) => MessageData.fromMap(json))
            .where((msg) => msg.type == MessageType.clip)
            .whereType<MessageData>()
            .toList();

        _currentOffset = clips.length;

        state = state.whenData((currentState) => currentState.copyWith(
              clips: clips,
              hasMore: data.length >= _pageSize,
            ));
      },
      onError: (error) {
        debugPrint('Clips stream error: $error');
        state = state.whenData((currentState) => currentState.copyWith(
              error: error.toString(),
            ));
      },
    );
  }

  /// Load more clips (pagination)
  Future<void> loadMoreClips() async {
    if (_currentSquadId == null) return;

    final currentState = state.value;
    if (currentState == null ||
        !currentState.hasMore ||
        currentState.isLoading) {
      return;
    }

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      final data = await SupabaseService.client
          .from('clips')
          .select()
          .eq('squad_id', _currentSquadId!)
          .order('created_at', ascending: false)
          .range(_currentOffset, _currentOffset + _pageSize - 1);

      final newClips = data
          .map((json) => MessageData.fromMap(json))
          .where((msg) => msg.type == MessageType.clip)
          .whereType<MessageData>()
          .toList();

      _currentOffset += newClips.length;

      state = AsyncData(currentState.copyWith(
        clips: [...currentState.clips, ...newClips],
        hasMore: newClips.length >= _pageSize,
        isLoading: false,
      ));
    } catch (e) {
      debugPrint('Error loading more clips: $e');
      state = AsyncData(currentState.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  /// Refresh clips (pull to refresh)
  Future<void> refreshClips() async {
    if (_currentSquadId == null) return;

    _currentOffset = 0;
    await _loadInitialClips(_currentSquadId!);
  }

  /// Mark clip as viewed (increment view count)
  Future<void> markClipAsViewed(String clipMessageId) async {
    if (_currentSquadId == null) return;

    try {
      // Get current view count
      final clipData = await SupabaseService.client
          .from('clips')
          .select('view_count')
          .eq('id', clipMessageId)
          .maybeSingle();

      final currentCount = (clipData?['view_count'] as int?) ?? 0;

      await SupabaseService.client
          .from('clips')
          .update({'view_count': currentCount + 1}).eq('id', clipMessageId);
    } catch (e) {
      debugPrint('Error marking clip as viewed: $e');
    }
  }

  /// Load clip of the day (most hyped in last 24 hours or manual selection)
  Future<MessageData?> _loadClipOfTheDay(String squadId) async {
    try {
      // First check for manually pinned clip of the day
      final squadData = await SupabaseService.client
          .from('squads')
          .select('clip_of_the_day_id')
          .eq('id', squadId)
          .maybeSingle();

      final clipOfTheDayId = squadData?['clip_of_the_day_id'];
      if (clipOfTheDayId != null) {
        final clipData = await SupabaseService.client
            .from('clips')
            .select()
            .eq('id', clipOfTheDayId)
            .maybeSingle();

        if (clipData != null) {
          return MessageData.fromMap(clipData);
        }
      }

      // Otherwise, get most hyped clip in last 24 hours
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final data = await SupabaseService.client
          .from('clips')
          .select()
          .eq('squad_id', squadId)
          .gte('created_at', yesterday.toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      if (data.isEmpty) return null;

      // Find clip with most hype reactions
      MessageData? mostHyped;
      int maxHype = 0;

      for (final json in data) {
        final msg = MessageData.fromMap(json);
        final hypeCount = msg.clipData?.hypeReactions.length ?? 0;
        if (hypeCount > maxHype) {
          maxHype = hypeCount;
          mostHyped = msg;
        }
      }

      return mostHyped;
    } catch (e) {
      debugPrint('Error loading clip of the day: $e');
      return null;
    }
  }

  /// Set manual clip of the day
  Future<void> setClipOfTheDay(String clipMessageId) async {
    if (_currentSquadId == null) return;

    try {
      await SupabaseService.client.from('squads').update(
          {'clip_of_the_day_id': clipMessageId}).eq('id', _currentSquadId!);

      // Reload clip of the day
      final clipOfTheDay = await _loadClipOfTheDay(_currentSquadId!);
      state = state.whenData((currentState) => currentState.copyWith(
            clipOfTheDay: clipOfTheDay,
          ));
    } catch (e) {
      debugPrint('Error setting clip of the day: $e');
    }
  }
}

/// Provider for clip notifier
final clipNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ClipNotifier, ClipState>(
  () => ClipNotifier(),
);
