# AASA — host this file

Spencer hosts this JSON. Do not commit `.env` or `GoogleService-Info.plist`.

```
BUNDLE_ID_IOS = com.example.codSquadApp
BUNDLE_ID_ANDROID = com.example.cod_squad_app
APPLE_TEAM_ID = K4ZTXPQ8J9
AASA_HOST = codsquad.app
FIREBASE_IOS_APP_ID = 1:756172684661:ios:496249d1653a47dc70e73c
FIREBASE_ANDROID_APP_ID = 1:756172684661:android:3466d7ce686fff4a70e73c
WIDGET_BUNDLE_ID = com.example.codSquadApp.PeacockLockWidget
```

## File to host

Serve **exactly** this body (no `.json` extension) at:

- `https://codsquad.app/.well-known/apple-app-site-association`
- `https://www.codsquad.app/.well-known/apple-app-site-association` (if www is used)

Requirements: HTTPS, HTTP 200, no redirect, `Content-Type: application/json`.

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["K4ZTXPQ8J9.com.example.codSquadApp"],
        "paths": ["/l/*"]
      }
    ]
  }
}
```

Repo copies (identical, include `apps` / `components` for iOS 13+):

- `ios/associated-domains/apple-app-site-association`
- `web/.well-known/apple-app-site-association`
- `web/apple-app-site-association`

`appIDs` is `APPLE_TEAM_ID.BUNDLE_ID_IOS` = `K4ZTXPQ8J9.com.example.codSquadApp`.

Path claimed: `/l/*` → `https://codsquad.app/l/<id>`.

Custom scheme `codsquadapp://lobby/<id>` stays working until DNS/AASA are live.

## Verify after host + DNS

```bash
curl -sI https://codsquad.app/.well-known/apple-app-site-association
curl -s https://codsquad.app/.well-known/apple-app-site-association
curl -s https://app-site-association.cdn-apple.com/a/v1/codsquad.app
```

Then delete-and-reinstall a device-signed Release build so iOS re-fetches AASA.
