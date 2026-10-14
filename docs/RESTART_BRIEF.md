# SquadSync restart brief

Written 2026-10-14 by Cod Lead. Docs only. No code changed, nothing merged, PR #1 untouched.

## Where it stands
- Last product commit: `bf3143f` (2026-09-20), version `3.4.187+189`.
- Branch: `cursor/revive-squadsync-be5c` only.
- Status: paused. On 2026-10-08 Spencer approved a reset to **chat first, then squads**, with a 3-bot team: Lead (Cod Lead), Builder (Cod Loop), Tester (App Tester). No code until Spencer approves the fix list.

## Definition of good (Spencer)
1. A group texting app whose chat feels as solid as iMessage or Discord.
2. A squad feature where group members see you're looking for players and tap to join.

## Open gates (need Spencer)
- **Go on the fix list:** sent 2026-10-08; awaiting approval.
- **Apple setup:** enable App Group `group.com.example.codSquadApp` on the app and widget App IDs (see `ios/PeacockLockWidget/SPENCER.txt`). Until then, device builds need App Groups and the widget stripped locally.
- **TestFlight:** a signed build and a weekly test group of 3 to 5 friends.
- **Real-phone check:** the chat audit was a code review only. The live database (for example the `reactions` table) and push banners were not verified.
- **Local build note:** `ios/Runner/GoogleService-Info.plist` is gitignored. A fresh checkout gets a placeholder and crashes on launch until the real plist is copied in.

## Why chat feels bad (audit, 2026-10-08)
- A failed send looks sent and then disappears. There is no failed state or retry.
- Busy groups can open on the oldest messages, and "load more" draws nothing.
- New messages trigger no notification, and unread badges aren't real counts.
- Scrolling is heavy: every bubble is blurred and the whole list is rebuilt on each update.
- Messages can be duplicated or missing. Typing, receipts, reactions, replies, edit, search, and camera are half-wired.
- The chat screen is crowded with lobby and Fill PIN controls.

## First 3 slices on reopen
1. **Honest send (L).** One message id; states for sending, sent, and failed; tap to retry; success only after the server has the row; remove the queue that never flushes. Done when a send made in airplane mode shows failed and retries cleanly on a real phone.
2. **Latest-first history (L).** Open on the newest messages, load older ones into the same list as you scroll up, stay at the bottom when you send, no jumping. Done when a group with more than 200 messages opens at the newest message on a phone.
3. **Chat notifications and real unread (M).** Saving a message notifies the other members, tapping the notification opens that chat, muted chats stay quiet, each group shows its own unread count, and opening a group clears only that group. Done when two phones exchange messages and both banners and badges are correct.

Also during Stage 1: move the lobby strip, gamepad, and Fill PIN bar off the chat screen. Park that code; don't delete it.

## After that
The rest of Stage 1: smooth scrolling, replies as quotes, photo plus caption as one message, a working camera, reactions, typing, in-chat search, and edit/delete. Read receipts come last.

Stage 2 is one "Looking for players" button. You pick the game, the open spots, and an optional time. Your groups see it and tap Join, the spot count updates live, and it clears when full or when the time passes.
