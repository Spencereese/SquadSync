# Morning brief

1. Tip `9c95267900af85d170dd6d7ab87046204646c577` / **3.4.138+140**. Product tip is Red A (`186215c`). Burst B docs/code sit on the same version line; `pubspec.yaml` was not bumped. Version stays `3.4.138+140`.

2. What landed
   - P0–P2 targeted tests green. Orphans / LFG promoted to the CI allowlist.
   - TestFlight checklist + `aps-environment` flavor comments (Flight).
   - Chat DB key is CSPRNG. No OS/locale fallback.
   - Unset client secrets park / fail soft. Cloud Run doc placeholders only.

3. CI: workflow still triggers on `main`/`master` only. Local / Harness green. GitHub Actions may not show on this draft PR branch.

4. Refused overnight
   - Merge
   - Portal clicks
   - Live SQL
   - Android id fix
   - Product features
   - HIPAA rewrite
   - Loop inventing slices

5. First 30 minutes (Spencer, portal only). Full runbook: `docs/TESTFLIGHT_CHECKLIST.md` §6.

   1. Sign in at [developer.apple.com/account](https://developer.apple.com/account).
   2. Membership details → copy the 10-character Team ID. Leave git at `TEAMID.com.example.codSquadApp` until step 15.
   3. Certificates, Identifiers & Profiles.
   4. Identifiers → open existing App ID `com.example.codSquadApp`. No `+`. No rename.
   5. Enable Push Notifications → Save.
   6. Enable Sign In with Apple → Save.
   7. Enable Associated Domains → Save.
   8. Enable Keychain Sharing if off → Save.
   9. Keys → create or reuse one APNs Auth Key. Download the `.p8` once. Note Key ID. Keep off git.
   10. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → create or open **Cod Squad** with bundle `com.example.codSquadApp`.
   11. Firebase project `cod-squad-a4c62` → iOS app `com.example.codSquadApp` → download real `GoogleService-Info.plist` to `ios/Runner/`. Do not commit.
   12. Same Firebase page → Cloud Messaging → upload the `.p8` + Key ID + Team ID.
   13. Supabase `sfckxrnoiwetmzdycqaa` → Authentication → URL Configuration → Redirect URLs must include `com.example.codSquadApp://auth-callback`.
   14. Supabase Providers: Apple (Team ID, Key ID, `.p8`) and Google (web client). iOS OAuth client stays `com.example.codSquadApp`.
   15. Paste Team ID into the three AASA files. Host at `https://codsquad.app/.well-known/apple-app-site-association`. Then delete-and-reinstall a device-signed Release build.

6. Next slice card: none overnight. Optional Harness — park for Spencer **yes**:
   - Widen CI to fire on the revive branch (docs-only workflow `on:`).
   - Grep leftover `dotenv.env[…]` throw sites outside the Burst B lease (may still crash features).

7. Can he invite 2 friends today? **No.** Portal gates (Team ID / AASA / APNs / `.p8` / GoogleService / TestFlight) are still blocked. The code path for a friends TestFlight is closer.

8. Burst B residuals
   - Treat previously committed Cloud Run literals as compromised. Spencer should rotate if they were ever live (git history retains them).
   - Remaining `dotenv.env[…]` throw sites outside the Burst B lease may still crash features — park as next optional Harness grep.
   - Soft-fail = empty IGDB / Twitch / voice / Grok without loud UI.
   - HARDCODED default `BACKEND_URL` in `voice_service` if unset (pre-existing).
   - Pubspec not bumped; version stays `3.4.138+140`.
