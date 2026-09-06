# AASA + Associated Domains (codesquad.app)

Repo prep so `https://codsquad.app/l/<id>` can open the app after Spencer
finishes Apple Developer portal + DNS/HTTPS hosting. Dart routing is
already on tip from ticket 12 — do not invent a second parser.

## Existing Universal Links router (ticket 12)

| Piece | Path |
| --- | --- |
| Parse | `lib/core/deep_link_routes.dart` → `locationForDeepLink` |
| Router alias | `lib/core/app_router.dart` → `DeepLinkRouter.locationFor` (calls the parse) |
| Live AppLinks | `locationForLiveAppLink` / `DeepLinkRouter.handleDeepLink` |
| Custom scheme (unchanged) | `codsquadapp://lobby/<id>` |

Mapping:

```
https://codsquad.app/l/<id>
https://www.codsquad.app/l/<id>
codsquadapp://lobby/<id>
        →  /squad?lobby_id=<id>
```

Simulator still swallows leftover `https://codsquad.app/…` Universal Links
(`shouldSwallowSimulatorAppLink`). Device builds consume them.

## Host-ready AASA (copy as-is after replacing TEAMID)

Canonical file: `apple-app-site-association` in this folder.

Host copies (keep identical):

- `web/.well-known/apple-app-site-association`
- `web/apple-app-site-association` (Apple root fallback)

Serve at:

- `https://codsquad.app/.well-known/apple-app-site-association`
- `https://www.codsquad.app/.well-known/apple-app-site-association` (if www is used)
- optional: `https://codsquad.app/apple-app-site-association`

HTTPS 200, `Content-Type: application/json`, no redirect, no `.json` suffix.
Path claimed: `/l/*`. Bundle ID in the file stays `TEAMID.com.example.codSquadApp`
until Spencer pastes the 10-character Team ID.

## Associated Domains entitlement

Template in this folder: `associated-domains.entitlements`

```
applinks:codsquad.app
applinks:www.codsquad.app
```

Live device entitlements already list those strings
(`ios/Runner/Runner.entitlements`). Simulator entitlements must stay
without `associated-domains`.

## BLOCKED

Portal toggles and DNS/hosting are not done in this slice. Exact Spencer
steps: `SPENCER.txt`.
