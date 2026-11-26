# Push tap: real-device APNs test

What the app does with a tap is covered by unit tests and simulator UI tests
(`-debug-push-open`, `-debug-push-open-after`). None of that proves delivery.
This checklist is the device test. Nothing here has been run on a phone yet.

## Before the test (Spencer / Grok Bot)

Confirm each one; don't assume it from an earlier note.

1. `sq8-notify-message` is deployed on `sfckxrnoiwetmzdycqaa` with
   `--no-verify-jwt` (the webhook secret is its check).
2. Function secrets exist: `SQ8_PUSH_WEBHOOK_SECRET`, `APNS_KEY_P8`,
   `APNS_KEY_ID`, `APNS_TEAM_ID` (`K4ZTXPQ8J9`), `APNS_BUNDLE_ID`
   (`com.spencereese.squadsync`). `APNS_SANDBOX` is unset or `true`: a Debug
   build from Xcode signs with `aps-environment = development`, so its tokens
   only work against the sandbox host.
3. A Database Webhook on `public.sq8_messages` INSERT points at the function
   URL with header `x-sq8-webhook-secret`.
4. The App ID `com.spencereese.squadsync` has Push Notifications on.
5. Both phones run a signed Debug build of the same commit, built on the Mac
   with automatic signing (team `K4ZTXPQ8J9`). Check the entitlement with
   `codesign -d --entitlements :- <path to SquadSync.app>`.

## On the phones

Phone A sends, phone B receives. Both are signed in and in the same squad.

1. On B, allow notifications when asked (it asks once you're signed in and in
   a squad). The function's response for the first message should show
   `apns` sent and no `key missing`.
2. **Background tap.** B on the home screen. A sends "push 1". B gets a banner.
   Tap it: the squad chat opens, "Opened this chat." shows at the top, and
   "push 1" is on screen.
3. **Killed tap (cold).** Swipe B's app away. A sends "push 2". Tap the banner:
   the app launches straight to the chat with "push 2" on screen.
4. **Sheet open, then tap (warm).** On B open Members (or Who's in, or the
   voice sheet), go to the home screen, A sends "push 3", tap the banner: the
   sheet is gone and "push 3" is on screen. If B was in the voice room it is
   still in it (the pill shows).
5. **Older message.** A sends "push 4", "push 5", "push 6" quickly. On B tap the
   "push 4" notification in Notification Center: the chat scrolls to "push 4",
   not the newest.
6. **In the chat already.** B open on the squad chat. A sends "push 7": no
   banner on B, and the message arrives in the chat.
7. **Signed out.** Sign out on B. A sends "push 8": B gets nothing (sign-out
   unregisters the token).

Record, for each step: pass or fail, the time (CT), and on a failure the
function log line for that message and a screenshot.

## Side-thread replies

Not run on a phone yet (nothing in this section has been run on a Mac or a phone). Before these steps, confirm (don't assume):

1. `supabase/migrations/20261126_0026_thread_push_targets.sql` is applied.
2. `sq8-notify-message` is redeployed from this branch with `--no-verify-jwt`.
3. A second Database Webhook on `public.sq8_thread_messages` INSERT points at
   the same function URL with the same `x-sq8-webhook-secret` header.
4. Everyone is in one squad: A, B, and a third member C.

No SQL editor is needed. Make the thread in the app, and reply from the app.

- **Make it.** On A tap the side threads button in the squad bar (at large
  text it's Members, then "Open side threads"), then New. Pick B only: that is a
  direct message, with no name. Tap Start and the new thread opens. C isn't in
  it, so C is the "outsider" in the steps below. Repeat with B and C picked and
  a name for a group, if you want the group wording ("A in <name>") checked too.
- **Check the list.** The thread shows in B's list (the last reply and its
  time) and not in C's. Starting the same DM again opens the one A has.
- **Replies come from the app.** A sends "thread 0" in the thread; whoever
  replies later opens the thread from their list. B's list shows the new
  preview within about 8 seconds.

8. **Banner.** B on the home screen. A reply "thread 1" arrives on B as
   "A in <title>" (or "A · Direct message"), body "thread 1". C gets nothing.
   A gets nothing.
9. **Background tap.** Tap it: the side thread opens over the chat with
   "thread 1" on screen. Close returns to the squad chat.
10. **Killed tap (cold).** Swipe B's app away, A replies "thread 2", tap: the
    app launches into the side thread with "thread 2" on screen.
11. **Sheet open, then tap (warm).** On B open Members, go home, A replies
    "thread 3", tap: the sheet is gone and the side thread shows "thread 3".
12. **In the side thread already.** Keep B in that side thread. A replies
    "thread 4": no banner on B, and "thread 4" shows in the thread within a
    few seconds. A squad-chat message from A while B is in the side thread
    does banner (the chat is covered).
13. **Reply back.** On B type "back" in the side thread and send: A gets a
    banner "B in <title>", and B gets nothing for their own reply.
14. **Left the squad.** If C (or anyone) leaves the squad while still a row in
    the thread, they get nothing.
15. **Signed out.** Sign out on B. A replies "thread 5": nothing arrives.

## Not covered

- The list shows no unread dot: the only read state is per squad
  (`sq8_chat_read_state`), so a dot would be a guess.
- A thread only exists for people who were seated when it was made; adding
  someone later isn't in the app.
- The `squad` payload type (squad card) is parsed and routed, but no server
  path sends it yet.
- Spot nudges are a design note in `supabase/functions/sq8-notify-message/README.md`.
