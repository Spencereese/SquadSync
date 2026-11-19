# sq8-voice-token (NOT DEPLOYED)

Mints a short-lived Stream Video **call token** for the caller's squad voice room.
Deploying it needs Spencer's yes; nothing in this PR deploys it.

## Request

`POST /functions/v1/sq8-voice-token` with the signed-in user's Supabase access token
(`Authorization: Bearer <jwt>`, `apikey: <anon key>`) and body `{"squad_id": "<uuid>"}`.

## Answers

| Status | Body | When |
|---|---|---|
| 200 | `{ok:true, api_key, token, user_id, call_type:"default", call_id:"sq8-<squad uuid>", expires_at}` | caller is in the squad |
| 400 | `{ok:false, reason:"bad_squad_id"}` | `squad_id` missing or not a uuid |
| 401 | `{ok:false, reason:"signed_out"}` | no bearer, or Supabase Auth rejects it |
| 403 | `{ok:false, reason:"not_a_member"}` | no `sq8_squad_members` row for (squad, caller) |
| 405 | `{ok:false, reason:"method_not_allowed"}` | not POST |
| 502 | `{ok:false, reason:"membership_unreadable"}` | the membership read failed |
| 503 | `{ok:false, reason:"voice_not_configured"}` | `STREAM_API_KEY` or `STREAM_API_SECRET` unset |

The app treats 404 (function not deployed) and 503 the same: "Voice isn't set up yet".

## How it checks

1. `GET /auth/v1/user` with the caller's token: the user id (no token parsing here).
2. Secrets present, else 503 (checked before any database read).
3. `GET /rest/v1/sq8_squad_members?squad_id=eq.X&user_id=eq.<caller>` **with the caller's
   own token**, so row level security (`sq8_members_select`, `sq8.is_member`) decides.
   No service role key is used.
4. HS256 JWT signed with `STREAM_API_SECRET`: `{user_id, call_cids:["default:sq8-<squad>"],
   iat: now-30s, exp: now+60min}`. `call_cids` limits the token to that one call.

The secret is never returned or logged. `api_key` is Stream's public app key.

## Secrets

`STREAM_API_KEY`, `STREAM_API_SECRET` (Supabase function secrets). `SUPABASE_URL` and
`SUPABASE_ANON_KEY` are provided by the platform.

## Deploy (only after Spencer's yes)

Files: `index.ts`, `voice.ts`. Entrypoint `index.ts`. `verify_jwt` may stay on (the
function also checks the session itself).

## Tests

```
deno test --allow-env supabase/functions/sq8-voice-token
```
