// Not deployed. Squad Steam presence for the signed-in caller.
// The caller's JWT is checked, then this function reads steam ids with the
// service role and asks Steam once for the squad. Steam ids are not returned.
// A missing STEAM_WEB_API_KEY answers not_set_up and calls nothing.

import {
  SummaryCache,
  type ParsedPlayer,
  parsePlayerSummaries,
  presenceKind,
  resolveToSteamId,
  summariesUrl,
} from "./steam.ts";

const jsonHeaders = { "content-type": "application/json" };
const cache = new SummaryCache(60_000);

type MemberLink = { userId: string; steamId: string | null };

function notSetUp(): Response {
  return Response.json({ status: "not_set_up" }, { headers: jsonHeaders });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const steamKey = Deno.env.get("STEAM_WEB_API_KEY");
  if (!url || !serviceKey || !anonKey || !steamKey) return notSetUp();

  const authorization = request.headers.get("Authorization") ?? "";
  const caller = await readUserId(url, anonKey, authorization);
  if (!caller) {
    return Response.json({ error: "signed_out" }, { status: 401, headers: jsonHeaders });
  }
  const body = request.method === "POST" ? await request.json().catch(() => ({})) : {};
  const op = typeof body.op === "string" ? body.op : "presence";

  if (op === "link") {
    const raw = typeof body.steam === "string" ? body.steam : "";
    const resolved = await resolveToSteamId(raw, steamKey, (target) => fetch(target));
    if ("error" in resolved) {
      const message = resolved.error === "invalid"
        ? "That is not a SteamID64 or a vanity URL."
        : resolved.error === "not_found"
        ? "Steam could not find that name."
        : "Steam presence not set up yet";
      return Response.json(
        { status: "rejected", message },
        { status: 400, headers: jsonHeaders },
      );
    }
    const saved = await writeLink(url, serviceKey, caller, resolved.steamId);
    if (!saved) return notSetUp();
    return Response.json(
      { status: "linked", steam_id: resolved.steamId },
      { headers: jsonHeaders },
    );
  }

  if (op === "unlink") {
    await deleteLink(url, serviceKey, caller);
    return Response.json({ status: "unlinked" }, { headers: jsonHeaders });
  }

  const squadId = await mySquad(url, serviceKey, caller);
  if (!squadId) {
    return Response.json({ error: "not_a_member" }, { status: 403, headers: jsonHeaders });
  }
  const links = await squadLinks(url, serviceKey, squadId);
  const steamIds = links.flatMap((link) => link.steamId ? [link.steamId] : []);
  const now = Date.now();
  let players = cache.get(steamIds, now);
  if (!players && steamIds.length > 0) {
    const response = await fetch(summariesUrl(steamIds, steamKey));
    if (!response.ok) return notSetUp();
    players = parsePlayerSummaries(await response.json());
    cache.set(steamIds, players, now);
  }
  const bySteam = new Map<string, ParsedPlayer>(
    (players ?? []).map((player) => [player.steamId, player]),
  );
  return Response.json({
    status: "ok",
    members: links.map((link) => memberPayload(link, bySteam.get(link.steamId ?? ""))),
  }, { headers: jsonHeaders });
});

function memberPayload(link: MemberLink, player: ParsedPlayer | undefined) {
  if (!link.steamId) return { user_id: link.userId, state: "not_linked" };
  const kind = presenceKind(player);
  if (kind === "playing") {
    return { user_id: link.userId, state: "playing", game: player?.game ?? "" };
  }
  if (kind === "private") return { user_id: link.userId, state: "private" };
  return { user_id: link.userId, state: "not_in_game" };
}

async function readUserId(
  url: string,
  anonKey: string,
  authorization: string,
): Promise<string | null> {
  if (!authorization.toLowerCase().startsWith("bearer ")) return null;
  const response = await fetch(`${url}/auth/v1/user`, {
    headers: { apikey: anonKey, Authorization: authorization },
  });
  if (!response.ok) return null;
  const body = await response.json() as { id?: string };
  return body.id ?? null;
}

async function rest(
  url: string,
  serviceKey: string,
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  return await fetch(`${url}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "content-type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

async function mySquad(
  url: string,
  serviceKey: string,
  userId: string,
): Promise<string | null> {
  const response = await rest(
    url,
    serviceKey,
    `sq8_squad_members?user_id=eq.${userId}&select=squad_id&limit=1`,
  );
  if (!response.ok) return null;
  const rows = await response.json() as { squad_id?: string }[];
  return rows[0]?.squad_id ?? null;
}

async function squadLinks(
  url: string,
  serviceKey: string,
  squadId: string,
): Promise<MemberLink[]> {
  const members = await rest(
    url,
    serviceKey,
    `sq8_squad_members?squad_id=eq.${squadId}&select=user_id`,
  );
  if (!members.ok) return [];
  const people = await members.json() as { user_id: string }[];
  const ids = people.map((row) => row.user_id).filter(Boolean);
  if (ids.length === 0) return [];
  const links = await rest(
    url,
    serviceKey,
    `sq8_steam_links?user_id=in.(${ids.join(",")})&select=user_id,steam_id`,
  );
  const linked = new Map<string, string>();
  if (links.ok) {
    for (const row of await links.json() as { user_id: string; steam_id: string }[]) {
      linked.set(row.user_id, row.steam_id);
    }
  }
  return ids.map((userId) => ({ userId, steamId: linked.get(userId) ?? null }));
}

async function writeLink(
  url: string,
  serviceKey: string,
  userId: string,
  steamId: string,
): Promise<boolean> {
  const response = await rest(url, serviceKey, "sq8_steam_links", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify({
      user_id: userId,
      steam_id: steamId,
      updated_at: new Date().toISOString(),
    }),
  });
  return response.ok;
}

async function deleteLink(url: string, serviceKey: string, userId: string): Promise<void> {
  await rest(url, serviceKey, `sq8_steam_links?user_id=eq.${userId}`, {
    method: "DELETE",
  });
}
