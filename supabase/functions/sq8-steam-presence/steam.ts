// Pure Steam Web API helpers. No network of their own.
// GetPlayerSummaries is one request for the whole squad.
// A private profile is not treated as a game, and a game name is never
// turned into a console.

export const STEAM_ID64 = /^[0-9]{17}$/;

const VANITY = /^[A-Za-z0-9_-]{2,32}$/;

export type SteamInput =
  | { kind: "id"; steamId: string }
  | { kind: "vanity"; vanity: string }
  | { kind: "invalid" };

export function interpretSteamInput(raw: string): SteamInput {
  const text = raw.trim();
  if (!text) return { kind: "invalid" };
  const profiles = text.match(/steamcommunity\.com\/profiles\/(\d{17})/i);
  if (profiles) return { kind: "id", steamId: profiles[1] };
  const named = text.match(/steamcommunity\.com\/id\/([^/?#]+)/i);
  if (named) {
    const vanity = decodeURIComponent(named[1]);
    return VANITY.test(vanity)
      ? { kind: "vanity", vanity }
      : { kind: "invalid" };
  }
  if (STEAM_ID64.test(text)) return { kind: "id", steamId: text };
  if (/^\d+$/.test(text)) return { kind: "invalid" };
  if (VANITY.test(text)) return { kind: "vanity", vanity: text };
  return { kind: "invalid" };
}

export function resolveVanityUrl(vanity: string, key: string): string {
  const params = new URLSearchParams({ key, vanityurl: vanity });
  return `https://api.steampowered.com/ISteamUser/ResolveVanityURL/v0001/?${params}`;
}

export function summariesUrl(steamIds: string[], key: string): string {
  const params = new URLSearchParams({
    key,
    steamids: [...steamIds].sort().join(","),
  });
  return `https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?${params}`;
}

type FetchLike = (url: string) => Promise<{ ok: boolean; json: () => Promise<unknown> }>;

export async function resolveToSteamId(
  raw: string,
  key: string,
  fetchImpl: FetchLike,
): Promise<{ steamId: string } | { error: "invalid" | "not_found" | "unavailable" }> {
  const input = interpretSteamInput(raw);
  if (input.kind === "invalid") return { error: "invalid" };
  if (input.kind === "id") return { steamId: input.steamId };
  let response: { ok: boolean; json: () => Promise<unknown> };
  try {
    response = await fetchImpl(resolveVanityUrl(input.vanity, key));
  } catch {
    return { error: "unavailable" };
  }
  if (!response.ok) return { error: "unavailable" };
  const body = await response.json();
  const record = body as { response?: { success?: number; steamid?: string } };
  const steamId = record.response?.steamid ?? "";
  if (record.response?.success === 1 && STEAM_ID64.test(steamId)) {
    return { steamId };
  }
  return { error: "not_found" };
}

export type ParsedPlayer = {
  steamId: string;
  isPublic: boolean;
  game: string | null;
  personaState: number;
};

export function parsePlayerSummaries(body: unknown): ParsedPlayer[] {
  const record = body as { response?: { players?: unknown } };
  const players = record.response?.players;
  if (!Array.isArray(players)) return [];
  const parsed: ParsedPlayer[] = [];
  for (const player of players) {
    if (!player || typeof player !== "object") continue;
    const row = player as {
      steamid?: unknown;
      communityvisibilitystate?: unknown;
      personastate?: unknown;
      gameextrainfo?: unknown;
    };
    const steamId = typeof row.steamid === "string" ? row.steamid : "";
    if (!STEAM_ID64.test(steamId)) continue;
    const game = typeof row.gameextrainfo === "string"
      ? row.gameextrainfo.trim()
      : "";
    parsed.push({
      steamId,
      isPublic: row.communityvisibilitystate === 3,
      game: game.length > 0 ? game : null,
      personaState: typeof row.personastate === "number" ? row.personastate : 0,
    });
  }
  return parsed;
}

export type PresenceKind = "private" | "playing" | "not_in_game";

/// A game name is shown only when Steam says the profile is public and
/// names the game. personaState alone is not a game, and it is not a console.
export function presenceKind(player: ParsedPlayer | undefined): PresenceKind {
  if (!player || !player.isPublic) return "private";
  if (player.game) return "playing";
  return "not_in_game";
}

export type CachedSummaries = {
  at: number;
  players: ParsedPlayer[];
};

export class SummaryCache {
  private readonly entries = new Map<string, CachedSummaries>();

  constructor(private readonly ttlMs = 60_000) {}

  static key(steamIds: string[]): string {
    return [...steamIds].sort().join(",");
  }

  get(steamIds: string[], now: number): ParsedPlayer[] | null {
    const hit = this.entries.get(SummaryCache.key(steamIds));
    if (!hit) return null;
    if (now - hit.at >= this.ttlMs) {
      this.entries.delete(SummaryCache.key(steamIds));
      return null;
    }
    return hit.players;
  }

  set(steamIds: string[], players: ParsedPlayer[], now: number): void {
    this.entries.set(SummaryCache.key(steamIds), { at: now, players });
  }
}
