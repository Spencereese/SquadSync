# AASA + Associated Domains (cod-squad-a4c62.web.app)

Repo prep so `https://cod-squad-a4c62.web.app/l/<id>` can open the app
after Spencer finishes Apple Developer portal + Firebase Hosting deploy.
Dart routing is already on tip from ticket 12 — do not invent a second
parser. Bots do **not** publish. Spencer must run `firebase deploy`
(hosting) himself.

## Existing Universal Links router (ticket 12)

| Piece | Path |
| --- | --- |
| Parse | `lib/core/deep_link_routes.dart` → `locationForDeepLink` |
| Router alias | `lib/core/app_router.dart` → `DeepLinkRouter.locationFor` (calls the parse) |
| Live AppLinks | `locationForLiveAppLink` / `DeepLinkRouter.handleDeepLink` |
| Custom scheme (unchanged) | `codsquadapp://lobby/<id>` |

Mapping:

```
https://cod-squad-a4c62.web.app/l/<id>
codsquadapp://lobby/<id>
        →  /squad?lobby_id=<id>
```

Friends tap shape: `https://cod-squad-a4c62.web.app/l/<id>`.

Simulator still swallows leftover https Universal Links
(`shouldSwallowSimulatorAppLink`). Device builds consume them.

## Host-ready AASA (write `APPLE_TEAM_ID = K4ZTXPQ8J9`)

Canonical file: `apple-app-site-association` in this folder.

Exact Spencer-click strings (do not invent others):

```
APPLE_TEAM_ID = K4ZTXPQ8J9
AASA_HOST = cod-squad-a4c62.web.app (Firebase Hosting scaffold — not e2e Universal Links. Spencer must firebase deploy --only hosting. Gate 1 blocked until he deploys AASA to that host AND device PASS.)
BUNDLE_ID_IOS = com.example.codSquadApp
WIDGET_BUNDLE_ID = com.example.codSquadApp.PeacockLockWidget
URL scheme: com.example.codSquadApp://auth-callback
FIREBASE_IOS_APP_ID = 1:756172684661:ios:496249d1653a47dc70e73c
```

Host copies (keep identical `appID` = `K4ZTXPQ8J9.com.example.codSquadApp`):

- `web/.well-known/apple-app-site-association`
- `web/apple-app-site-association` (Apple root fallback)

Serve at:

- `https://cod-squad-a4c62.web.app/.well-known/apple-app-site-association`
- optional: `https://cod-squad-a4c62.web.app/apple-app-site-association`

HTTPS 200, `Content-Type: application/json`, no redirect, no `.json` suffix.
Path claimed: `/l/*`. If a copy still shows `TEAMID`, replace it with
**`K4ZTXPQ8J9`** when hosting. AASA is scaffold-only until Spencer
deploys hosting and a device PASSes.

## Associated Domains entitlement

Template in this folder: `associated-domains.entitlements`

```
applinks:cod-squad-a4c62.web.app
```

Live device entitlements already list that string
(`ios/Runner/Runner.entitlements`). Simulator entitlements must stay
without `associated-domains`.

## BLOCKED

Portal toggles and `firebase deploy` (hosting) are not done in this
slice. Gate 1 Universal Links stay blocked until Spencer deploys AASA
to `cod-squad-a4c62.web.app` **and** a device PASS. Exact Spencer
steps: `SPENCER.txt`.
