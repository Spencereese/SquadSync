# Squad message push

This function is not deployed. It does not contain a key. Applying the migration, creating the Firebase apps, and setting the secrets are Spencer's steps.

## What it does

On an insert into `sq8_messages`, it asks `sq8.message_push_targets(squad, sender)` for device tokens. That query keeps current members and drops the sender. It sends one FCM HTTP v1 message per token:

`POST https://fcm.googleapis.com/v1/projects/<project id>/messages:send`

The project id comes from the service-account JSON. The access token is a JWT signed with that account's private key, Web Crypto, scope `https://www.googleapis.com/auth/firebase.messaging`. The token is cached until a minute before it expires.

The data payload is:

```json
{ "type": "squad_message", "squad_id": "<uuid>", "message_id": "<uuid>" }
```

The same three fields are copied next to `aps` so an iOS tap still has them. Android `collapse_key` and APNs `apns-collapse-id` / `thread-id` are `squad:<squad id>`.

If FCM answers `UNREGISTERED` or `INVALID_ARGUMENT`, the function calls `sq8_drop_device_token` with the service role and deletes that token. It does not trust a client-supplied recipient list.

If `FCM_SERVICE_ACCOUNT_JSON` or the webhook secret is missing or unreadable, the function returns `notifications off` and sends nothing.

## Secrets Spencer provides

Set these as Supabase function secrets. Do not commit them and do not paste them into the repo.

| Name | Where it comes from |
| --- | --- |
| `SQ8_PUSH_WEBHOOK_SECRET` | A long random string Spencer invents. The same value is the webhook header below. |
| `FCM_SERVICE_ACCOUNT_JSON` | The raw JSON of a Google service account whose key can call the FCM HTTP v1 API. The file has `project_id`, `client_email`, and `private_key`. |
| `SUPABASE_URL` | Already injected for hosted functions. Do not copy it into git. |
| `SUPABASE_SERVICE_ROLE_KEY` | Already injected for hosted functions. This is the bypass-RLS key. Do not copy it into git. |

There is no `FCM_SERVER_KEY`. The legacy `https://fcm.googleapis.com/fcm/send` endpoint is not used.

iOS delivery also needs an APNs auth key uploaded to Firebase, not to this repo:

- Apple Developer → Keys → Apple Push Notifications service (APNs), a `.p8` file.
- Key ID, and Team ID `K4ZTXPQ8J9`.
- Bundle id `com.spencereese.squadsync`.
- Firebase → Project settings → Cloud Messaging → Apple app → upload the `.p8`.

Android needs `google-services.json`. iOS needs `GoogleService-Info.plist`. Both stay out of git, and `lib/firebase_options.dart` stays out of git. Without those files the app says "Notifications off: not set up yet" and does not call `sq8_register_device_token`.

## Console steps

1. Apply `supabase/migrations/20261110_0012_device_tokens.sql` on the project. It is not applied by this agent.
2. In Firebase, create the project. Add the iOS app and the Android app with bundle id `com.spencereese.squadsync`. Download `GoogleService-Info.plist` and `google-services.json` onto the build machine only. Run `flutterfire configure` there if you want `firebase_options.dart`. Do not commit any of those three files.
3. Apple Developer → Keys → create the APNs `.p8`. Note the Key ID and Team ID `K4ZTXPQ8J9`. Upload the `.p8` in Firebase → Project settings → Cloud Messaging → Apple app. In Xcode, turn on Push Notifications for the Runner target.
4. Google Cloud → the Firebase project → IAM → create a service account that can send FCM (role "Firebase Cloud Messaging API Admin", or a key allowed to call `https://www.googleapis.com/auth/firebase.messaging`). Create a JSON key. Enable the Firebase Cloud Messaging API for the project.
5. From a machine that is already logged into the Supabase CLI, set the secrets without echoing them: `supabase secrets set SQ8_PUSH_WEBHOOK_SECRET=...` and `supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat the-service-account.json)"`. The JSON is one secret value, not a file in git.
6. Deploy only when those secrets exist: `supabase functions deploy sq8-notify-message --no-verify-jwt`. The webhook is authenticated by `SQ8_PUSH_WEBHOOK_SECRET`, not by a user JWT.
7. In the Supabase dashboard, add a Database Webhook on `public.sq8_messages` INSERT. Point it at the function URL. Header: `x-sq8-webhook-secret: <the same secret>`.
8. Put the two Firebase config files on the iOS and Android build machines. Until they are present, the phone stays on "Notifications off: not set up yet". After they are present, sign-in asks for permission, reads the FCM token, and calls `sq8_register_device_token`. Sign-out calls `sq8_unregister_device_token` and deletes the local token.

## Spot nudges, design only

Do not build this until file 12 is applied and `sq8-notify-message` is deployed with FCM. No table, function, or client change belongs to this note.

When someone calls a spot (`sq8_spot_calls` insert, status `open`), notify the members of that squad who are not starters and who have no RSVP row yet. The caller is not notified. A starter is already in, so they are not notified. A member who has already answered in or out is not notified. Send once, at the moment the call is created. Do not send again for an RSVP, a lock, an end, or a cancel. The payload type is `spot_call`, with `squad_id` and the call id, on the same FCM HTTP v1 path as a squad message.
