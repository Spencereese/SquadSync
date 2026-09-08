# TestFlight checklist (P5 Cod Flight)

Friends follow this file. **Nobody on this slice logs into Apple, Firebase,
Supabase, or App Store Connect.** Spencer clicks the portal. This agent
does not.

Bundle ID stays **`com.example.codSquadApp`**. Do not rename. Do not merge
or retarget PR #1. Do not commit secrets. Do not bump `pubspec.yaml`.

```
Branch:  cursor/revive-squadsync-be5c
Tip:     3.4.157+159 (docs-only Spencer-click notes — pubspec not bumped)
PR #1:   do not merge / do not retarget
Upload:  Spencer (not this slice)
```

## Slice ID constants (exact — do not invent others)

```
APPLE_TEAM_ID = K4ZTXPQ8J9
AASA_HOST = codsquad.app (scaffold only — DNS NOT live; Gate 1 Universal Links blocked until Spencer points domain + hosts apple-app-site-association)
BUNDLE_ID_IOS = com.example.codSquadApp
WIDGET_BUNDLE_ID = com.example.codSquadApp.PeacockLockWidget
URL scheme: com.example.codSquadApp://auth-callback
FIREBASE_IOS_APP_ID = 1:756172684661:ios:496249d1653a47dc70e73c
```

`APPLE_TEAM_ID` is known. Write **`K4ZTXPQ8J9`** — do not leave a `TEAMID`
placeholder for Spencer to paste later. AASA files / hosting still use
`K4ZTXPQ8J9.com.example.codSquadApp`. Gate 1 Universal Links stay blocked
until DNS + `apple-app-site-association` are live on `codsquad.app`.

---

## 1. `aps-environment` is a flavor — never a silent flip

Push uses **`development`** or **`production`** depending on the Xcode
SDK + configuration. **Do not edit the committed `development` strings
in place** to ship TestFlight. That silent flip is what breaks the
simulator (and can leak device applinks into Launch Services).

| Flavor | When | Entitlements file | `aps-environment` | Associated Domains |
| --- | --- | --- | --- | --- |
| **Simulator** | `iphonesimulator*` (Debug or Release) | `ios/Runner/Runner.simulator.entitlements` | **`development`** | **Off** (must stay off) |
| **Device Debug** | `iphoneos*` + Debug | `ios/Runner/Runner.entitlements` | **`development`** (sandbox APNs) | On (device file) |
| **Device Release / Archive / TestFlight / App Store** | `iphoneos*` + Release / Profile / Archive | Release-only overlay — **not** the simulator file | **`production`** | On (device file) |

Wiring already in the repo (do not change it this week):

- Default `CODE_SIGN_ENTITLEMENTS` = `Runner/Runner.simulator.entitlements`
- `CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]` = simulator file (`development`, no applinks)
- `CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]` = `Runner/Runner.entitlements`

### How friends apply `production` without breaking sim

1. Leave **`Runner.simulator.entitlements`** at `development`. Never set
   production there.
2. Leave the committed **`Runner.entitlements`** `aps-environment` at
   `development` so Debug device + any leaked default stay sandbox-safe.
3. For the **TestFlight / App Store archive only**, point the
   **Release** (and Profile) *iphoneos* configuration at a
   **Release-only** entitlements copy that has `aps-environment` =
   `production`. Do that in Xcode:
   - Open `ios/Runner.xcworkspace` (not `.xcodeproj`)
   - Select the **Runner** target → **Signing & Capabilities**
   - In the configuration picker, choose **Release** (not Debug)
   - Push Notifications environment for that Release configuration =
     **Production**
   - Or: duplicate `Runner.entitlements` locally as a Release overlay
     and set `CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]` on **Release /
     Profile only** to that overlay
4. Confirm Debug + Simulator still read `development`.
5. Do **not** commit a flip of the simulator file. Do **not** change the
   shared Debug value and push it as the new default.

`flutter run` / Simulator = **development**. `flutter build ipa` /
Xcode **Product → Archive** = **production** on the Release overlay.

---

## 2. AASA / Associated Domains — scaffold only (`AASA_HOST` not live)

Repo AASA `appID` / `appIDs` for hosting:

```
K4ZTXPQ8J9.com.example.codSquadApp
```

That is `APPLE_TEAM_ID` + `BUNDLE_ID_IOS`. The Team ID is **`K4ZTXPQ8J9`**
— write it. Do not invent a second Team ID. Do not wait to “paste Team ID
later.”

`AASA_HOST = codsquad.app` is **scaffold only — DNS NOT live; Gate 1
Universal Links blocked until Spencer points domain + hosts
apple-app-site-association**.

Files Spencer publishes **after** DNS/HTTPS is pointed at an origin
(same `appID` string in all three):

- `ios/associated-domains/apple-app-site-association`
- `web/.well-known/apple-app-site-association`
- `web/apple-app-site-association`

If a copy still shows a `TEAMID` placeholder, replace that placeholder
with **`K4ZTXPQ8J9`** when hosting. Do not host `TEAMID.com.example.codSquadApp`.

Device applinks already listed on `ios/Runner/Runner.entitlements`:

```
applinks:sfckxrnoiwetmzdycqaa.supabase.co
applinks:lobbiesync.app
applinks:www.lobbiesync.app
applinks:codsquad.app
applinks:www.codsquad.app
```

Simulator entitlements must **not** claim `associated-domains`.
Host AASA at `https://codsquad.app/.well-known/apple-app-site-association`
(HTTPS 200, `Content-Type: application/json`, no redirect, no `.json`).
Path claimed: `/l/*`. Until that host is live, `codsquadapp://lobby/<id>`
still works; `https://codsquad.app/l/<id>` will not open the app.

---

## 3. Friend build recipe (local Mac — no portal login from a bot)

### Files that must exist on disk and must **never** be committed

Copy / download these locally. `.gitignore` already blocks them.

| Path | How you get it | Why |
| --- | --- | --- |
| `.env` | Copy `.env.example` → `.env` and fill real values | `--dart-define-from-file=.env` (not a Flutter asset) |
| `ios/Runner/GoogleService-Info.plist` | Firebase Console → iOS app `com.example.codSquadApp` (`FIREBASE_IOS_APP_ID = 1:756172684661:ios:496249d1653a47dc70e73c`) → download | Real FCM / Analytics. Example plist is `YOUR_` placeholders only |
| `android/app/google-services.json` | Firebase Android app (if you also run Android) | Gitignored. Not this week's iOS archive |
| `*.p8` (APNs Auth Key) | Apple Developer → Keys (step 9) | Upload to Firebase Cloud Messaging. Never commit |
| `backend/.env` | Local backend only | Not required for the IPA |
| `backend/service-account.json` / `service-account.json` | GCP / Firebase admin | Never commit |

`GoogleService-Info.plist.example` is **not** a substitute. A build-phase
script copies the example only so Xcode has a file; device APNs/FCM will
not register against `YOUR_` values.

### Archive commands

From the repo root, on a Mac with Xcode + signing team:

```bash
flutter pub get

# Preferred: IPA for App Store Connect / TestFlight
flutter build ipa \
  --release \
  --dart-define-from-file=.env \
  --export-options-plist=ios/export_options.plist
```

`ios/export_options.plist` already sets `method` = `app-store` and lists
`APPLE_TEAM_ID = K4ZTXPQ8J9`. Spencer confirms Membership matches
**`K4ZTXPQ8J9`** (step 2). If it differs, stop and ask — do not invent a
second bundle ID.

Xcode archive (same Release flavor):

```bash
flutter build ios --release --dart-define-from-file=.env
# then open ios/Runner.xcworkspace → Product → Archive → Distribute App
# → App Store Connect
```

Always pass **`--dart-define-from-file=.env`**. Dart-defines are
compile-time. Hot restart does not inject them. Do not use leftover
`com.squadsync.app`.

After upload: wait for processing in App Store Connect → TestFlight →
add internal testers. First install: Accept “Open in Cod Squad?” if the
custom-scheme prompt appears.

---

## 4. Auth URL scheme (verified in repo)

Canonical Supabase / OAuth return (do not change):

```
URL scheme: com.example.codSquadApp://auth-callback
```

Verified on tip:

| Location | What it has |
| --- | --- |
| `ios/Runner/Info.plist` | URL type `supabase.auth.callback` → scheme `com.example.codSquadApp` |
| `ios/Runner/Info.simulator.plist` | Same scheme (sim must register it too) |
| `lib/core/auth_redirect.dart` | `kIosBundleId` + `kSupabaseAuthRedirect` = that URL |
| `.env.example` | Comment lists the same redirect |

In-app lobby/chat deep links stay `codsquadapp://lobby/<id>` — that is
**not** the auth callback.

Widget extension id (identity only — not a second App ID to create this
week unless Apple already requires it for the widget target):

```
WIDGET_BUNDLE_ID = com.example.codSquadApp.PeacockLockWidget
```

---

## 5. Android applicationId mismatch (footnote only — do not fix)

| Platform | Id | Status |
| --- | --- | --- |
| iOS bundle | `com.example.codSquadApp` | Parked. Do not change. (`BUNDLE_ID_IOS`) |
| Android `applicationId` / namespace | `com.example.cod_squad_app` | **Mismatch. Do not fix this week.** |

Leave Android as-is. No `applicationId` “fix”, no Firebase Android
rename, no store listing work in this slice.

---

## 6. Fifteen-step “Spencer in the portal” runbook

Spencer only. Checkbox as you click. Do not create a second App ID.
Do not rename `BUNDLE_ID_IOS = com.example.codSquadApp`.

- [ ] **1.** Open [developer.apple.com/account](https://developer.apple.com/account) and sign in as Spencer
- [ ] **2.** Open **Membership details** (Account → Membership). Confirm
      the **10-character Team ID** is **`APPLE_TEAM_ID = K4ZTXPQ8J9`**.
      Write `K4ZTXPQ8J9` on AASA (`K4ZTXPQ8J9.com.example.codSquadApp`).
      Do not leave a `TEAMID` placeholder
- [ ] **3.** Click **Certificates, Identifiers & Profiles**
- [ ] **4.** Click **Identifiers**. Open the existing App ID
      **`com.example.codSquadApp`**. Do **not** click the **+** button.
      Do **not** rename the bundle
- [ ] **5.** Enable **Push Notifications** → **Save**
- [ ] **6.** Enable **Sign In with Apple** → **Save**
- [ ] **7.** Enable **Associated Domains** → **Save**
- [ ] **8.** Enable **Keychain Sharing** if it is off → **Save**
      (repo already uses `$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)`)
- [ ] **9.** Click **Keys** → create or reuse one **APNs Auth Key**.
      Download the `.p8` once. Note **Key ID**. Keep the file off git
- [ ] **10.** Open [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
      → **My Apps** → create or open **Cod Squad** with bundle ID
      **`com.example.codSquadApp`** (the existing App ID from step 4)
- [ ] **11.** Open Firebase Console → project **`cod-squad-a4c62`** →
      **Project settings** → confirm the **iOS** app is
      **`BUNDLE_ID_IOS = com.example.codSquadApp`** and
      **`FIREBASE_IOS_APP_ID = 1:756172684661:ios:496249d1653a47dc70e73c`**.
      Download the real `GoogleService-Info.plist` to
      `ios/Runner/GoogleService-Info.plist`. Confirm `BUNDLE_ID` inside is
      `com.example.codSquadApp` and `GOOGLE_APP_ID` is that iOS app id.
      Do not commit
- [ ] **12.** Same Firebase page → **Cloud Messaging** → Apple app
      configuration → upload the `.p8` from step 9 + **Key ID** +
      **`APPLE_TEAM_ID = K4ZTXPQ8J9`**
- [ ] **13.** Open Supabase → project **`sfckxrnoiwetmzdycqaa`** →
      **Authentication** → **URL Configuration** → **Redirect URLs**
      must include `com.example.codSquadApp://auth-callback`.
      Do not add leftover `com.squadsync.app://…`
- [ ] **14.** Supabase **Authentication** → **Providers**:
      - **Apple:** Team ID **`K4ZTXPQ8J9`**, Key ID + `.p8` (step 9),
        Services ID that does **not** change the app bundle ID
      - **Google:** Web client ID + secret; iOS OAuth client stays bundle
        `com.example.codSquadApp`
- [ ] **15.** Host AASA (Gate 1 still blocked until this is live). Write
      `K4ZTXPQ8J9.com.example.codSquadApp` in all three AASA files from
      section 2. Point **`AASA_HOST = codsquad.app`** DNS + HTTPS, then
      serve the file at
      `https://codsquad.app/.well-known/apple-app-site-association`
      (and www if you use it). Then delete-and-reinstall a **device-signed
      Release** build so iOS re-fetches AASA.
      **AASA_HOST = codsquad.app (scaffold only — DNS NOT live; Gate 1
      Universal Links blocked until Spencer points domain + hosts
      apple-app-site-association).** Until then,
      `codsquadapp://lobby/<id>` still works

---

## Connect extras (Spencer, first upload)

- [ ] App Privacy: answer from what the binary actually collects
      (account email, user content, identifiers, usage/diagnostics).
      No health / precise location / IAP on tip
- [ ] Export Compliance: **No** — HTTPS/TLS only.
      `ITSAppUsesNonExemptEncryption` is already `false` in Info.plist
- [ ] Signing team on the archive = **`APPLE_TEAM_ID = K4ZTXPQ8J9`**
      (the Membership team that owns App ID `com.example.codSquadApp`)
- [ ] Release/Archive `aps-environment` = **production** via the flavor
      in section 1 — **not** a committed flip of the simulator file

Out of scope for this slice: TestFlight upload itself, SQL, `.env`
commit, bundle ID rename, Android id “fix”, merging PR #1, opening a
new PR, flipping simulator `aps-environment` to production.
