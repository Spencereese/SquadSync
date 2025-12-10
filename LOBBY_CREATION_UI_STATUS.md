# Lobby Creation UI Implementation - Status Report

## ✅ Completed Features

### 1. Game Selection Sheet (`lib/chat/game_selection_sheet.dart`)
- **Purpose**: Modal bottom sheet for selecting games when creating lobbies
- **Features**:
  - IGDB game search with real-time results
  - Display of user's pinned games
  - Max spots slider (2-12 players)
  - Game cover art display with fallback icons
  - Haptic feedback on selection
  - Error handling with SnackBars

- **Usage**:
  ```dart
  await GameSelectionSheet.show(
    context,
    onGameSelected: (gameName, maxSpots) {
      // Handle game selection
    },
  );
  ```

### 2. LobbyNotifier Enhancement
- **New Method**: `createLobby()`
  - Parameters: `chatGroupId`, `gameName`, `maxSpots`, `isPublic`
  - Creates lobby linked to chat group via `chat_group_id`
  - Returns lobby ID for further operations
  - Automatic state reload after creation
  - Comprehensive debug logging

- **Location**: `lib/presentation/notifiers/lobby_notifier.dart`
- **Integration**: Uses `CreateLobbyForGroup` use case
- **Error Handling**: Try-catch with rethrow for caller handling

### 3. Chat Screen Integration
- **Added Gamepad Button**: IconButton in `NeonChatAppBar`
  - Shows only for user group chats (`isUserGroup`)
  - Triggers `_handleLobbyCreation()` workflow
  - Glass morphic design matching app theme

- **Lobby Creation Flow**:
  1. User taps gamepad icon
  2. Game selection sheet appears
  3. User selects game and max spots
  4. Lobby created with haptic feedback
  5. Success SnackBar shown
  6. Spots sheet opens automatically

- **Location**: `lib/chat/chat_screen.dart`
- **Features**:
  - Haptic feedback (medium on select, light on success, heavy on error)
  - Loading indicators during creation
  - Error handling with user-friendly messages
  - Automatic spots sheet display after creation

### 4. UI/UX Enhancements
- **NeonChatAppBar**: Added optional `onGamepadPressed` callback
- **Imports**: Added `game_selection_sheet.dart` and `spots_sheet.dart`
- **Visual Feedback**: SnackBars for all states (loading, success, error)
- **Accessibility**: Haptic patterns for different outcomes

## 🚧 Remaining Work

### 1. Rename `squad_tab` to `lobbies_tab`
**Files to rename**:
- `lib/squad_tab/` → `lib/lobbies_tab/`
- `lib/squad_tab/squad_tab.dart` → `lib/lobbies_tab/lobbies_tab.dart`
- Update all imports referencing `squad_tab/`

**Navigation updates**:
- Update `lib/screens/squad_tab_screen.dart` imports
- Update main navigation/router references
- Verify icon/label in bottom navigation

### 2. Public Lobby Creation in Lobbies Tab
**Requirements**:
- Add FloatingActionButton with "Create Public Lobby" label
- Show GameSelectionSheet with `showPublicToggle: true`
- Add chat group dropdown for optional linking:
  ```dart
  // Get user's chat groups from ChatNotifier
  final userGroups = ref.watch(chatNotifierProvider)
    .value?.userChatGroups.values.toList();
  ```
- Set `isPublic: true` when creating lobby
- Show spots sheet after creation

**Implementation location**: `lib/lobbies_tab/lobbies_tab.dart`

### 3. Update `spots_sheet.dart`
**Required changes**:
- Check if user is lobby creator (compare `currentUser.id` with `lobby.created_by`)
- Show `is_public` toggle switch (only for creators)
- Add game picker if `gameName` is empty:
  ```dart
  if (widget.gameName.isEmpty) {
    // Show GameSelectionSheet first
    // Then navigate to SpotsSheet with selected game
  }
  ```
- Update Supabase query to update `is_public` field

### 4. Discovery System Enhancement
**DiscoveryNotifier updates** (`lib/presentation/notifiers/discovery_notifier.dart`):
```dart
Future<List<Lobby>> getPublicLobbies({
  String? gameName,
  int? minSpots,
  bool activeOnly = true,
}) async {
  var query = SupabaseService.client
    .from('lobbies')
    .select()
    .eq('is_public', true);
    
  if (gameName != null) {
    query = query.eq('game_name', gameName);
  }
  
  if (activeOnly) {
    query = query.eq('is_active', true);
  }
  
  final response = await query;
  return response.map((json) => Lobby.fromJson(json)).toList();
}
```

**Discovery UI**:
- Filter by game name
- Show lobby details (game, spots filled/total, created by)
- Join button (calls `LobbyNotifier.joinLobby()`)
- Real-time updates for lobby availability

### 5. Database Schema Verification
**Ensure `lobbies` table has**:
- `chat_group_id` (UUID, nullable, FK to `chat_groups.id`)
- `is_public` (BOOLEAN, default: false)
- `is_active` (BOOLEAN, default: true)
- `created_by` (TEXT, FK to `users.uid`)
- `game_name` (TEXT, indexed for queries)
- `max_spots` (INTEGER)
- `squad_spots` (JSON array)

**Indexes needed**:
```sql
CREATE INDEX idx_lobbies_public ON lobbies(is_public, is_active, game_name);
CREATE INDEX idx_lobbies_chat_group ON lobbies(chat_group_id);
```

### 6. Testing Checklist
- [ ] Create private lobby from chat → members receive notification stub
- [ ] Create public lobby from tab → visible in discovery
- [ ] Claim spots in newly created lobby
- [ ] Toggle `is_public` as lobby creator
- [ ] Search/filter public lobbies by game
- [ ] Join public lobby from discovery
- [ ] Verify haptic feedback on all interactions
- [ ] Test error cases (no internet, invalid data)
- [ ] Verify lobby-chat group linkage
- [ ] Test offline behavior with SQLite cache

## 📝 Code Snippets for Remaining Work

### Public Lobby Creation Button (lobbies_tab.dart)
```dart
floatingActionButton: FloatingActionButton.extended(
  onPressed: () async {
    HapticFeedback.mediumImpact();
    await GameSelectionSheet.show(
      context,
      showPublicToggle: true,
      onGameSelected: (gameName, maxSpots) async {
        // Show chat group selector (optional)
        final chatGroupId = await _showChatGroupSelector(context);
        
        final lobbyNotifier = ref.read(lobbyNotifierProvider.notifier);
        await lobbyNotifier.createLobby(
          chatGroupId: chatGroupId ?? '', // Empty for standalone public lobbies
          gameName: gameName,
          maxSpots: maxSpots,
          isPublic: true,
        );
        
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Public lobby created!')),
        );
      },
    );
  },
  icon: Icon(Icons.add),
  label: Text('Create Public Lobby'),
),
```

### is_public Toggle (spots_sheet.dart)
```dart
// In _SpotsSheetState build method, after header
if (_isCreator) {
  SwitchListTile(
    title: Text('Public Lobby'),
    subtitle: Text('Allow others to discover and join this lobby'),
    value: _isPublic,
    onChanged: (value) async {
      setState(() => _isPublic = value);
      HapticFeedback.selectionClick();
      
      await SupabaseService.client
        .from('lobbies')
        .update({'is_public': value})
        .eq('id', widget.chatGroupId);
        
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lobby ${value ? "public" : "private"}')),
      );
    },
  ),
}
```

## 🔄 Migration Notes

### Squad → Lobby Terminology
- All "Squad" references in lobby context have been renamed to "Lobby"
- `squad_tab` directory should be renamed to `lobbies_tab`
- Preserve "Squad" for app branding (SquadSync name remains)
- Discovery/matchmaking features can use "Lobby" terminology

### Database Changes
- `squads` table renamed to `lobbies`
- Added `chat_group_id` for linking
- Added `is_public` for discovery
- Atomic creation with chat groups via `chat_remote_datasource_impl.dart`

## 🎯 Next Steps Priority

1. **High Priority**:
   - Rename `squad_tab` → `lobbies_tab` for consistency
   - Add public lobby creation button
   - Implement DiscoveryNotifier public lobby queries

2. **Medium Priority**:
   - Add `is_public` toggle to spots_sheet
   - Test private lobby notifications
   - Verify database indexes

3. **Low Priority**:
   - Enhance discovery filters (skill level, region, etc.)
   - Add lobby chat preview in discovery
   - Implement lobby favorites/bookmarks

## 📦 Files Modified

1. `lib/chat/game_selection_sheet.dart` - **NEW**
2. `lib/presentation/notifiers/lobby_notifier.dart` - Added `createLobby()` method
3. `lib/chat/widgets/neon_chat_app_bar.dart` - Added gamepad button
4. `lib/chat/chat_screen.dart` - Added `_handleLobbyCreation()` workflow
5. `lib/core/injection.dart` - Registered `CreateLobbyForGroup`
6. `lib/data/datasources/chat_remote_datasource_impl.dart` - Atomic lobby creation (previous commit)

## 🐛 Known Issues

1. **Provider naming**: Some files have `ln.ln.lobbyNotifierProvider` double-namespace (fixed with sed in most files)
2. **Import cleanup**: Some unused imports remain in modified files
3. **Missing imports**: Files referencing old Squad classes need updated imports

## 💡 Recommendations

1. **User Notifications**: Implement real notification system for lobby creation (currently stubbed)
2. **Lobby Lifecycle**: Add automatic cleanup for inactive lobbies (cron job or Cloud Function)
3. **Analytics**: Track lobby creation/join metrics for feature optimization
4. **Permissions**: Implement lobby kick/ban functionality for creators
5. **Rich Presence**: Show "In Lobby" status in user profiles
