# Gates (device e2e)

Identity (exact — do not invent others):

```
APPLE_TEAM_ID = K4ZTXPQ8J9
AASA_HOST = cod-squad-a4c62.web.app
BUNDLE_ID_IOS = com.example.codSquadApp
WIDGET_BUNDLE_ID = com.example.codSquadApp.PeacockLockWidget
URL scheme: com.example.codSquadApp://auth-callback
FIREBASE_IOS_APP_ID = 1:756172684661:ios:496249d1653a47dc70e73c
```

`AASA_HOST` is Firebase Hosting (`cod-squad-a4c62.web.app`). Bots do **not**
publish. Spencer must run `firebase deploy` (hosting) himself.

Friends tap shape: `https://cod-squad-a4c62.web.app/l/<id>`.

Repo scaffold is not e2e. Do not treat a green host string as PASS.

## Gate 1 — Associated Domains + hosted AASA (blocked)

Universal Links stay **blocked** until Spencer:

1. Deploys AASA to
   `https://cod-squad-a4c62.web.app/.well-known/apple-app-site-association`
   (`firebase deploy` / hosting). Bots do not publish.
2. Device **PASS**: delete-and-reinstall a device-signed Release build, then
   tap `https://cod-squad-a4c62.web.app/l/<id>` from Notes or Safari and the
   app opens the lobby.

Until both are done, Gate 1 is blocked.

## Gate 2 — Device push e2e

Device-signed build with real `GoogleService-Info.plist` + APNs. Simulator
is not this gate. Portal clicks stay Spencer.

## Gate 3 — Lock-screen widget

`WIDGET_BUNDLE_ID = com.example.codSquadApp.PeacockLockWidget` (identity
only). Device lock-screen widget e2e is Spencer/device — not this docs
slice.
