# TestFlight checklist (Spencer)

Phase C prep. **Do not merge PR #1.** This file is the portal / App Store
Connect runbook — the slice that added it did **not** click Apple Developer,
Firebase, Supabase, or App Store Connect.

Bundle ID stays **`com.example.codSquadApp`**. Do not rename. Do not commit
`.env`. Do not apply Supabase migrations from this checklist.

Branch: `cursor/revive-squadsync-be5c`

```
Tip (at this slice): 3.4.100+102
PR: https://github.com/Spencereese/SquadSync/pull/1 — do not merge
Upload / TestFlight: Spencer (not this slice)
```

Repo already has the iOS target, entitlements, URL schemes, and Firebase
Analytics wiring. What is left is portal + Connect work, then an archive.

---

## 0. Before you start

- [ ] Apple Developer account with a team (export_options currently lists
      Team ID `K4ZTXPQ8J9` — confirm this is the live team; paste the
      10-character Team ID into AASA files if it differs)
- [ ] App Store Connect access for that team
- [ ] Firebase project `cod-squad-a4c62` (GCP number `756172684661`)
- [ ] Supabase project `sfckxrnoiwetmzdycqaa`
- [ ] A real `ios/Runner/GoogleService-Info.plist` on disk (gitignored).
      `GoogleService-Info.plist.example` is placeholders only — device
      APNs/FCM will not register against `YOUR_` values
- [ ] Do **not** change `PRODUCT_BUNDLE_IDENTIFIER` in
      `ios/Runner.xcodeproj/project.pbxproj` (must stay
      `com.example.codSquadApp`)

---

## 1. App ID

Identifiers → App IDs. Use the **existing** App ID. Do not create a new one.

| Field | Value |
| --- | --- |
| Bundle ID | `com.example.codSquadApp` (Explicit) |
| Display name in repo | Cod Squad |
| Team ID (export_options) | `K4ZTXPQ8J9` — confirm in Membership |

Capabilities to have **on** this App ID (repo entitlements already claim them):

- [ ] Push Notifications
- [ ] Sign In with Apple
- [ ] Associated Domains
- [ ] Keychain Sharing (entitlements use
      `$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)`)

Do **not** enable a second bundle ID. Do **not** rename to `com.squadsync.app`
or `com.codsquad.app`.

---

## 2. Push / APNs

Repo:

- `ios/Runner/Runner.entitlements` → `aps-environment` is currently
  **`development`**. A TestFlight / App Store archive needs **`production`**.
- `UIBackgroundModes` includes `remote-notification`
- `AppDelegate` skips `registerForRemoteNotifications()` when the plist
  still has `YOUR_` placeholders
- FCM lives on `firebase_messaging`; database stays on Supabase

Portal:

- [ ] Certificates, Identifiers & Profiles → Keys → create (or reuse) an
      **APNs Auth Key** (`.p8`). One key per team is enough
- [ ] Note Key ID + Team ID. Upload that key to **Firebase Console →
      Project settings → Cloud Messaging → Apple app configuration**
      (not the old `.cer`/CSR flow unless you already use it)
- [ ] Confirm the iOS app in Firebase uses bundle ID
      `com.example.codSquadApp`
- [ ] For the TestFlight archive, set `aps-environment` to `production`
      on the device entitlements (`ios/Runner/Runner.entitlements`).
      Simulator entitlements stay without production APNs / applinks
- [ ] Put the **real** `GoogleService-Info.plist` at
      `ios/Runner/GoogleService-Info.plist` (gitignored). Do not commit it
- [ ] After a signed device build: grant notification permission in-app,
      then confirm an FCM token is minted (peacock / lobby lock / chat
      already use `NotificationService`)

---

## 3. Sign in with Apple

Repo:

- Entitlement: `com.apple.developer.applesignin` = `Default`
- Live path: `AuthServiceSupabase.signInWithApple()` → Supabase OAuth
  with `redirectTo: kSupabaseAuthRedirect`
  (`com.example.codSquadApp://auth-callback`)
- Info.plist URL scheme: `com.example.codSquadApp`

Portal / Supabase (you click; this slice did not):

- [ ] App ID has **Sign In with Apple** enabled
- [ ] Supabase Authentication → Providers → Apple:
      - Service ID / client: `com.example.codSquadApp` (or the Services ID
        you create **without** changing the app bundle ID)
      - Team ID, Key ID, and the `.p8` (repo has
        `backend/AuthKey_X3W3HSAXZF.p8` for Key ID `X3W3HSAXZF` — rotate
        if that key is retired)
- [ ] Redirect URL on the Apple provider and in Supabase URL config:
      `com.example.codSquadApp://auth-callback`
- [ ] Device test: Sign in with Apple returns to the app, session restores
      after cold start (`SupabaseService.ensureFreshSession`)

---

## 4. Associated Domains

Repo prep is already on tip (do not invent a second parser):

| Piece | Path |
| --- | --- |
| Entitlements (device) | `ios/Runner/Runner.entitlements` |
| Template | `ios/associated-domains/associated-domains.entitlements` |
| AASA | `ios/associated-domains/apple-app-site-association` |
| Host copies | `web/.well-known/apple-app-site-association`, `web/apple-app-site-association` |
| Portal/DNS steps | `ios/associated-domains/SPENCER.txt` |
| Dart route | `locationForDeepLink` → `/squad?lobby_id=` |

Device applinks already listed:

```
applinks:sfckxrnoiwetmzdycqaa.supabase.co
applinks:lobbiesync.app
applinks:www.lobbiesync.app
applinks:codsquad.app
applinks:www.codsquad.app
```

Simulator entitlements must **not** claim `associated-domains`.

Spencer:

- [ ] Enable Associated Domains on App ID `com.example.codSquadApp`
- [ ] Replace `TEAMID` in all three AASA files with the 10-character Team ID
      → `TEAMID.com.example.codSquadApp` becomes
      `<TEAMID>.com.example.codSquadApp`
- [ ] Host AASA at `https://codsquad.app/.well-known/apple-app-site-association`
      (HTTPS 200, `Content-Type: application/json`, no redirect, no `.json`)
- [ ] Reinstall a device-signed build, then tap `https://codsquad.app/l/<id>`
- [ ] Until DNS/AASA are live, `codsquadapp://lobby/<id>` still works

---

## 5. Firebase iOS

Repo:

- `lib/firebase_options.dart` iOS:
  - project `cod-squad-a4c62`
  - appId `1:756172684661:ios:99ecq9sd74qvt9ufs28os52j9g33h1v9`
  - `iosBundleId: com.example.codSquadApp`
- `Firebase.initializeApp` + `setAnalyticsCollectionEnabled(true)` in
  `lib/main.dart`
- Analytics is **Analytics + FCM only**. No Firebase database

Console (you click):

- [ ] Firebase project has an **iOS** app whose bundle ID is exactly
      `com.example.codSquadApp` (do not add a different bundle ID)
- [ ] Download the real `GoogleService-Info.plist` and place it at
      `ios/Runner/GoogleService-Info.plist` (gitignored)
- [ ] Confirm `BUNDLE_ID` inside that plist is `com.example.codSquadApp`
- [ ] Confirm `GOOGLE_APP_ID` / `GCM_SENDER_ID` match
      `DefaultFirebaseOptions.ios` (or re-run FlutterFire and update
      `firebase_options.dart` **without** changing the bundle ID)
- [ ] Enable Google Analytics for the iOS app
- [ ] DebugView (optional): Xcode scheme `-FIRDebugEnabled` and watch
      `lobby_join`, `peacock_offer`, `peacock_lock`, `session_rate`,
      `ready_check` — no uid / email / display name params

---

## 6. Google OAuth

Repo (native Google Sign-In → Supabase `signInWithIdToken`):

| Piece | Value |
| --- | --- |
| iOS client | `756172684661-99ecq9sd74qvt9ufs28os52j9g33h1v9.apps.googleusercontent.com` |
| Web / server client | `756172684661-pv3rscsdd548cb5r6orrs6u2bvu1oi6e.apps.googleusercontent.com` |
| Reversed URL scheme | `com.googleusercontent.apps.756172684661-99ecq9sd74qvt9ufs28os52j9g33h1v9` |
| Info.plist | `GIDClientID` + `google.sign.in` URL type |
| Config | `lib/core/google_auth_config.dart` (`.env` wins over bundled IDs) |

Console:

- [ ] Google Cloud / Firebase OAuth client of type **iOS** uses bundle ID
      `com.example.codSquadApp`
- [ ] iOS URL scheme in the client matches `REVERSED_CLIENT_ID` from the
      real plist
- [ ] Web client (type 3) is the `serverClientId` / `GOOGLE_WEB_CLIENT_ID`
- [ ] Supabase Authentication → Providers → Google: Client ID + secret
      from that web client; skip nonce as required by `signInWithIdToken`
- [ ] Device test: Google Sign-In returns an ID token and a Supabase
      session. Simulator needs the reversed scheme in Info.plist (already
      present)

`.env` keys (do not commit): `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_WEB_CLIENT_ID`.

---

## 7. Supabase redirect allow-list

Canonical redirect (must match Info.plist + `kSupabaseAuthRedirect`):

```
com.example.codSquadApp://auth-callback
```

Authentication → URL Configuration:

- [ ] **Redirect URLs** include `com.example.codSquadApp://auth-callback`
- [ ] Do **not** add leftover `com.squadsync.app://…`
- [ ] Site URL can stay the Supabase project URL
      (`https://sfckxrnoiwetmzdycqaa.supabase.co`)
- [ ] Additional allow-list if you still use browser OAuth:
      `https://sfckxrnoiwetmzdycqaa.supabase.co/auth/v1/callback`
- [ ] Keep `codsquadapp://` for in-app lobby/chat deep links — that is
      **not** the auth callback

Deep-link scheme vs auth scheme:

| Scheme | Use |
| --- | --- |
| `codsquadapp://lobby/<id>` | Product deep link → `/squad?lobby_id=` |
| `com.example.codSquadApp://auth-callback` | Google / Apple / magic-link return |

---

## 8. Privacy nutrition (App Store Connect)

App Privacy questionnaire. Answer from **what the app actually does**.
Do not claim data you do not collect.

Collects (typical for this binary — confirm in Connect):

| Category | Examples in product | Linked to identity? | Used for tracking? |
| --- | --- | --- | --- |
| Contact info | Email (account) | Yes (account) | No |
| Identifiers | Supabase user id, FCM token / device id | Yes | No |
| User content | Chat, photos, clips, profile image | Yes | No |
| Usage data | Firebase Analytics events below | No (events are not PII) | No |
| Diagnostics | Crash / error events (`error_occurred`) | No | No |

Does **not** collect (unless you add it later): Health, Precise Location,
Financial Info, Purchases (no IAP on tip), Sensitive Info.

Third-party partners to list if Connect asks: Firebase (Analytics + FCM),
Supabase (auth + database), Google Sign-In, Apple (Sign in with Apple),
Agora (voice/video), IGDB/Twitch (game metadata).

Product Analytics events (no PII params):

- `lobby_join`
- `peacock_offer`
- `peacock_lock`
- `session_rate`
- `ready_check`

Do not send uid, email, display name, tokens, or raw lobby/squad ids on
those events (`lib/services/squad_analytics.dart` strips them).

Privacy Nutrition Labels in Connect are **not** the same as
`PrivacyInfo.xcprivacy` (Apple Privacy Manifest). Add a manifest in a
later slice if App Store starts rejecting the upload for missing
`NSPrivacyAccessedAPITypes`. This checklist does not invent that file.

Usage-string keys already in Info.plist: photo library, camera,
microphone, speech recognition, notifications, Siri.

---

## 9. Export compliance

The app uses HTTPS / TLS only (Supabase, Firebase, Google, Agora, IGDB).
No custom cryptography.

Repo: `ITSAppUsesNonExemptEncryption` = `false` in
`ios/Runner/Info.plist` and `ios/Runner/Info.simulator.plist` so App Store
Connect does not prompt on every upload.

Connect (if still asked on the first version):

- [ ] Export Compliance: **No** (app uses only exemption-eligible HTTPS)
- [ ] Do not answer Yes unless you add non-exempt crypto

---

## 10. Archive / TestFlight (Spencer — not this slice)

Do **not** do these in the analytics/docs slice. When you are ready:

- [ ] `aps-environment` = `production` on the device entitlements
- [ ] Real `GoogleService-Info.plist` in the Runner bundle
- [ ] Signing team = the Apple team that owns App ID
      `com.example.codSquadApp`
- [ ] `ios/export_options.plist` method `app-store`, Team ID confirmed
- [ ] Archive from `ios/Runner.xcworkspace` (not `.xcodeproj`)
- [ ] Upload; wait for processing; add internal testers
- [ ] First install: Accept “Open in Cod Squad?” if the custom scheme
      prompt appears; Sign in with Apple or Google; grant notifications

Out of scope for this file’s slice: TestFlight upload itself, SQL,
`.env` commit, bundle ID rename, merging PR #1.

---

## Analytics events (already in the binary)

Logged through existing `FirebaseAnalytics.instance`. Helpers:
`lib/services/squad_analytics.dart`.

| Event | When | Params (no PII) |
| --- | --- | --- |
| `lobby_join` | Lobby join / LFG `joinMatched` | `source`, `game_name` |
| `peacock_offer` | Peacock queue assign / LFG match | `source`, `game_name`, `seat_index` |
| `peacock_lock` | All seated Ready → lock | `seated_count`, `ready_count` |
| `session_rate` | Win/Loss rating persist | `stars`, `result`, `skipped` |
| `ready_check` | Seated Ready / timeout | `seated_count`, `ready_count`, `outcome` |

Verify in Firebase DebugView on a device build. Units mock analytics
(`SquadAnalytics.logHook`) and cover helper + happy-path call sites:
`test/services/squad_analytics_test.dart`,
`test/presentation/notifiers/lobby_notifier_test.dart`,
`test/services/matchmaking_queue_tracker_test.dart`.
