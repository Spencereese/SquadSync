# Squad Steam presence

This function is not deployed. It does not contain a Steam key. Applying the migration, creating the key, and deploying are Spencer's steps.

The phone sends the signed-in person's JWT. The function checks that they belong to one squad, reads that squad's Steam links with the service role, and calls GetPlayerSummaries once. SteamID64 values are not in the response. A vanity name is resolved with ResolveVanityURL before it is stored. Summaries are cached in the function for about 60 seconds.

A private profile is reported as private. A public profile in a game is reported with Steam's `gameextrainfo` only. The function does not guess a console.

Until this is deployed, or if `STEAM_WEB_API_KEY` is missing, the function is not called successfully and the phone says "Steam presence not set up yet".

## Human gates

1. Apply `supabase/migrations/20261110_0015_steam_links.sql`. It is not applied. It does not grant `anon` or `public`.
2. Create a Steam Web API key at https://steamcommunity.com/dev/apikey for this app. Do not commit it.
3. From a machine already logged into the Supabase CLI, set it without echoing: `supabase secrets set STEAM_WEB_API_KEY=...`. Hosted functions already receive `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`.
4. Deploy only when that secret exists: `supabase functions deploy sq8-steam-presence`.
5. Each member links a SteamID64 or a `steamcommunity.com/id/...` vanity in their profile. A private Steam profile shows "Steam profile private". A member with no link shows "Steam not linked".

Xbox is not part of this function. See `docs/xbox-presence.md`.
