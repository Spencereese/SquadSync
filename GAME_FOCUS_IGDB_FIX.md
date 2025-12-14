# Game Focus IGDB Integration - Create Group Dialog

## Changes Made

Updated the "Create New Group" dialog to pull games from IGDB instead of using a hardcoded list.

### File Modified
- **[lib/chat/dialogs/group_actions_dialog.dart](lib/chat/dialogs/group_actions_dialog.dart)**

### What Changed

#### Before
- Hardcoded list of 11 games in a dropdown
- No search capability
- Static text-only display

#### After
- **Dynamic game loading** from IGDB via `GameNotifier.loadPopularGames()`
- **Search functionality** using `GameSearchDelegate` (full IGDB search)
- **Visual game tiles** with cover art using `GameTile` widget
- **Horizontal scrollable gallery** of popular games
- **Loading states** and **retry mechanism** for failed loads

### Features

1. **Popular Games Section**
   - Loads top 10 popular games from IGDB on dialog open
   - Displays as horizontal scrollable gallery with cover art
   - Shows loading spinner while fetching
   - Retry button if loading fails

2. **Search Button**
   - "Search IGDB" button in header
   - Opens full game search dialog
   - Search across entire IGDB database
   - Same search interface used elsewhere in the app

3. **Selected Game Display**
   - Shows selected game with full details (list style)
   - Close button overlay to deselect
   - Highlighted with cyan border
   - Game name stored in group description with 🎮 emoji prefix

4. **Graceful Fallbacks**
   - Shows message if no games load
   - Retry button for manual reload
   - Continues to work even if IGDB is unavailable

### Usage

When creating a new group:

1. **Select from popular games:**
   - Scroll horizontally through popular game tiles
   - Tap any game to select it

2. **Search for specific game:**
   - Click "Search IGDB" button
   - Type game name
   - Select from search results

3. **Deselect game:**
   - Click the red X button on selected game
   - Or tap the game tile again

4. **Create group:**
   - Selected game (if any) is added to group description as "🎮 {Game Name}"
   - Helps members know what game the group focuses on

### Technical Details

**State Management:**
```dart
Game? _selectedGame;           // Selected game object
List<Game> _popularGames = []; // Popular games from IGDB
bool _loadingGames = false;    // Loading state
```

**IGDB Integration:**
```dart
// Load popular games via GameNotifier
final result = await ref.read(gameNotifierProvider.notifier).loadPopularGames();

// Search games via GameSearchDelegate
final selectedGame = await GameSearchDelegate.show(context, ref: ref);
```

**Game Display:**
```dart
// Horizontal gallery
GameTile(
  game: game,
  style: GameTileStyle.grid, // 120x160 with cover art
  onTap: () => setState(() => _selectedGame = game),
)

// Selected game display
GameTile(
  game: _selectedGame!,
  style: GameTileStyle.list, // Full details with description
)
```

### Benefits

1. **Live data** - Always shows current popular games from IGDB
2. **Better UX** - Visual tiles with cover art instead of text dropdown
3. **More games** - Access to entire IGDB database via search
4. **Consistency** - Uses same game selection UI as rest of app
5. **Offline support** - GameNotifier handles fallbacks to cached data

### Testing

Test these scenarios:
- [ ] Dialog opens and loads popular games
- [ ] Horizontal scroll through popular games works
- [ ] Tapping game selects it
- [ ] "Search IGDB" opens search dialog
- [ ] Search and select game from results
- [ ] Selected game shows with close button
- [ ] Close button deselects game
- [ ] Creating group with game adds to description
- [ ] Retry button works if loading fails
- [ ] Works offline (shows cached games)

### Related Files

- [lib/presentation/notifiers/game_notifier.dart](lib/presentation/notifiers/game_notifier.dart) - IGDB integration
- [lib/widgets/game_tile.dart](lib/widgets/game_tile.dart) - Game display component
- [lib/widgets/game_search_delegate.dart](lib/widgets/game_search_delegate.dart) - Game search UI
- [lib/domain/entities/game.dart](lib/domain/entities/game.dart) - Game entity model
