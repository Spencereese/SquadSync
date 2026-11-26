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

Not run on a phone yet. Before these steps, confirm (don't assume):

1. `supabase/migrations/20261126_0025_thread_push_targets.sql` is applied.
2. `sq8-notify-message` is redeployed from this branch with `--no-verify-jwt`.
3. A second Database Webhook on `public.sq8_thread_messages` INSERT points at
   the same function URL with the same `x-sq8-webhook-secret` header.
4. A side thread exists with A and B in it, and a third squad member C who is
   not in it. The app can't create side threads yet: make one in the SQL
   editor (an `sq8_threads` row plus `sq8_thread_members` rows for A and B),
   or reuse one that already exists.

A replies in the side thread. The app can reply only inside a side thread a
push opened, so the first reply comes from the SQL editor (an
`sq8_thread_messages` row with A as `sender_id`) or from a side thread B
opened.

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

- The app has no list of side threads and can't start one. A side thread opens
  only from its reply's notification.
- The `squad` payload type (squad card) is parsed and routed, but no server
  path sends it yet.
- Spot nudges are a design note in `supabase/functions/sq8-notify-message/README.md`.
