# Friends launch

## now

Tip ~`186215c` v3.4.138+140. P0–P2 CI green. P5 Flight done. Burst A CSPRNG landed. Burst B in flight.

## next

Red Burst B secret quarantine + docs redact; Harness sqlite verify; then MORNING_BRIEF.

## residuals

- Client secrets still read via dotenv/fromEnvironment (IGDB/Twitch/Agora/XAI) — Burst B stubbing
- `CLOUD_RUN_DEPLOYMENT.md` previously contained literal-looking secrets — redact in Burst B
- Portal: TEAMID/AASA/APNs/.p8/GoogleService/TestFlight still Spencer
- Live SQL blocked
- CI workflow still only on main/master push (revive PR may not run GH Actions until configured)

## blocked-on-Spencer

- YES to live SQL
- Team ID confirm (`ios/export_options.plist` lists `K4ZTXPQ8J9`)
- APNs `.p8` → Firebase
- Real `GoogleService-Info.plist` on the build machine (gitignored)
- Associated Domains + AASA on `codsquad.app`
- TestFlight upload + internal group
- Friend list: who is on CoD

Flight parked: TEAMID/AASA host, `.env`+GoogleService on build machine, production aps on Release archive only, TestFlight upload.

## SHA

`186215c064b96cf746ea713f6b1c44e39425e9a5`

## version

`3.4.138+140`
