# Friends launch

## now

Tip `9c95267` v3.4.138+140. P0–P2 green. P5 Flight done. Red A+B done. Loop idle (no failing friend slice).

## next

`docs/MORNING_BRIEF.md`. Workers IDLE. Optional Harness widen CI to fire on revive branch (`on:` only) — park for Spencer.

## residuals

- Secure-storage fail hard in release
- Existing devices keep old chat keys
- CI workflow only on `main`/`master`
- Portal / TestFlight still Spencer
- Live SQL blocked

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

`9c95267900af85d170dd6d7ab87046204646c577`

## version

`3.4.138+140` — product tip from Red A (`186215c`). Burst B did not bump `pubspec.yaml`.
