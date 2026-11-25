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

## Not covered

- Side threads (`sq8_thread_messages`) have no push: the webhook is on
  `sq8_messages` only, and the iOS app has no side-thread screen yet.
- The `squad` payload type (squad card) is parsed and routed, but no server
  path sends it yet.
- Spot nudges are a design note in `supabase/functions/sq8-notify-message/README.md`.
