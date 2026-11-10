# Squad message push

This function is not deployed. It does not contain a key. Applying the migration and deploying the function are Spencer's steps.

## What it does

On an insert into `sq8_messages`, it asks `sq8.message_push_targets(squad, sender)` for device tokens. That query keeps current members and drops the sender. The data payload is only:

```json
{ "type": "squad_message", "squad_id": "<uuid>", "message_id": "<uuid>" }
```

The phone opens that squad's chat when the signed-in person is in it. Otherwise it says the notification is for a squad they are not in.

If `FCM_SERVER_KEY` or the webhook secret is missing, the function returns `notifications off` and sends nothing.

## Secrets Spencer provides

Set these in the Supabase function secrets. Do not commit them and do not paste them into the repo.

| Name | Where it comes from |
| --- | --- |
| `SQ8_PUSH_WEBHOOK_SECRET` | A long random string Spencer invents. The same value is the webhook header below. |
| `FCM_SERVER_KEY` | Firebase console → Project settings → Cloud Messaging → Server key, or a legacy server key. Prefer the HTTP v1 service account later; this stub uses the legacy key header. |
| `SUPABASE_URL` | Already injected for hosted functions. Do not copy it into git. |
| `SUPABASE_SERVICE_ROLE_KEY` | Already injected for hosted functions. This is the bypass-RLS key. Do not copy it into git. |

iOS delivery also needs an APNs auth key uploaded to Firebase, not to this repo:

- Apple Developer → Keys → Apple Push Notifications service (APNs), a `.p8` file.
- Key ID and Team ID `K4ZTXPQ8J9`.
- Bundle id `com.spencereese.squadsync`.
- Firebase → Project settings → Cloud Messaging → Apple app → upload the `.p8`.

Android needs `google-services.json`. iOS needs `GoogleService-Info.plist`. Both stay out of git.

## Console steps

1. Apply `supabase/migrations/20261110_0012_device_tokens.sql` on the project. It is not applied by this agent.
2. Create a Firebase project, add the iOS and Android apps with the bundle id above, and download the two plist/json files onto the phones' build machines only.
3. Upload the APNs `.p8` into Firebase. Enable the iOS Push Notifications capability in Xcode for the Runner target.
4. `supabase secrets set SQ8_PUSH_WEBHOOK_SECRET=... FCM_SERVER_KEY=...` from a machine that already has the Supabase CLI logged in. Do not echo the values.
5. Deploy only when those secrets exist: `supabase functions deploy sq8-notify-message --no-verify-jwt`. The webhook is authenticated by `SQ8_PUSH_WEBHOOK_SECRET`, not by a user JWT.
6. In the Supabase dashboard, add a Database Webhook on `public.sq8_messages` INSERT. Point it at the function URL. Header: `x-sq8-webhook-secret: <the same secret>`.
7. Install the push client SDK in a later change. Until that SDK has a real token, the app shows "Notifications off" and does not call `sq8_register_device_token`.
