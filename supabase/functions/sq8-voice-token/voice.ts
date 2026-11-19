// sq8-voice-token: a short-lived Stream Video user token for the caller's squad
// voice room. Pure logic and the request handler, with the network and the
// environment passed in, so the tests run without Supabase or Stream.
//
// Order: the caller's Supabase session (401), the request (400), the Stream
// secrets (503, "voice isn't set up"), squad membership under the caller's own
// row level security (403), then a token for exactly one call.

export const CALL_TYPE = "default";
/** Seconds a token lives. The app asks again before it runs out. */
export const TOKEN_TTL_SECONDS = 60 * 60;
/** Allowance for a phone clock that runs a little ahead of Stream's. */
export const CLOCK_SKEW_SECONDS = 30;

export type Env = (name: string) => string | undefined;
export type Fetch = (input: string, init?: RequestInit) => Promise<Response>;

export interface Deps {
  env: Env;
  fetch: Fetch;
  /** Seconds since the epoch. */
  now: () => number;
}

const jsonHeaders = { "content-type": "application/json" };

export function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** One room per squad. Stream call ids allow letters, digits, "-" and "_". */
export function callIdFor(squadId: string): string {
  return `sq8-${squadId.toLowerCase()}`;
}

export function missingStreamSecrets(env: Env): string[] {
  return ["STREAM_API_KEY", "STREAM_API_SECRET"].filter((name) => !(env(name) ?? "").trim());
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlJSON(value: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(value)));
}

export interface StreamClaims {
  user_id: string;
  call_cids: string[];
  iat: number;
  exp: number;
}

export function claimsFor(userId: string, squadId: string, now: number): StreamClaims {
  return {
    user_id: userId,
    // A call token: Stream only lets it into this one call.
    call_cids: [`${CALL_TYPE}:${callIdFor(squadId)}`],
    iat: now - CLOCK_SKEW_SECONDS,
    exp: now + TOKEN_TTL_SECONDS,
  };
}

/** HS256 JWT, signed with the Stream API secret (Stream's server-side user tokens). */
export async function signStreamToken(claims: StreamClaims, secret: string): Promise<string> {
  const head = base64urlJSON({ alg: "HS256", typ: "JWT" });
  const body = base64urlJSON(claims);
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${head}.${body}`));
  return `${head}.${body}.${base64url(new Uint8Array(signature))}`;
}

function bearer(request: Request): string | null {
  const header = request.headers.get("Authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1].trim() : null;
}

/** The caller's user id from Supabase Auth, or null for no or a bad session. */
async function callerId(deps: Deps, url: string, anonKey: string, token: string): Promise<string | null> {
  const response = await deps.fetch(`${url}/auth/v1/user`, {
    headers: { apikey: anonKey, Authorization: `Bearer ${token}` },
  });
  if (!response.ok) return null;
  const user = await response.json().catch(() => null);
  return user && typeof user.id === "string" && UUID.test(user.id) ? user.id : null;
}

type Membership = "member" | "not_member" | "unknown";

/** Reads the caller's own sq8_squad_members row with the caller's token, so
 *  row level security (sq8_members_select) decides; no service role. */
async function membership(deps: Deps, url: string, anonKey: string, token: string, squadId: string, userId: string): Promise<Membership> {
  const query = new URLSearchParams({
    select: "user_id",
    squad_id: `eq.${squadId}`,
    user_id: `eq.${userId}`,
    limit: "1",
  });
  const response = await deps.fetch(`${url}/rest/v1/sq8_squad_members?${query}`, {
    headers: { apikey: anonKey, Authorization: `Bearer ${token}`, Accept: "application/json" },
  });
  if (!response.ok) return "unknown";
  const rows = await response.json().catch(() => null);
  if (!Array.isArray(rows)) return "unknown";
  return rows.length > 0 ? "member" : "not_member";
}

export async function handle(request: Request, deps: Deps): Promise<Response> {
  if (request.method === "OPTIONS") return new Response(null, { status: 204 });
  if (request.method !== "POST") return reply(405, { ok: false, reason: "method_not_allowed" });

  const url = (deps.env("SUPABASE_URL") ?? "").replace(/\/+$/, "");
  const anonKey = deps.env("SUPABASE_ANON_KEY") ?? "";
  const token = bearer(request);
  if (!token) return reply(401, { ok: false, reason: "signed_out" });
  if (!url || !anonKey) return reply(503, { ok: false, reason: "voice_not_configured" });

  const userId = await callerId(deps, url, anonKey, token);
  if (!userId) return reply(401, { ok: false, reason: "signed_out" });

  const body = await request.json().catch(() => null);
  const squadId = body && typeof body.squad_id === "string" ? body.squad_id.trim() : "";
  if (!UUID.test(squadId)) return reply(400, { ok: false, reason: "bad_squad_id" });

  // Honest "not set up": never a token, never a pretend room.
  if (missingStreamSecrets(deps.env).length > 0) {
    return reply(503, { ok: false, reason: "voice_not_configured" });
  }

  const member = await membership(deps, url, anonKey, token, squadId, userId);
  if (member === "not_member") return reply(403, { ok: false, reason: "not_a_member" });
  if (member === "unknown") return reply(502, { ok: false, reason: "membership_unreadable" });

  const now = Math.floor(deps.now());
  const claims = claimsFor(userId, squadId, now);
  const streamToken = await signStreamToken(claims, deps.env("STREAM_API_SECRET")!.trim());
  return reply(200, {
    ok: true,
    api_key: deps.env("STREAM_API_KEY")!.trim(),
    token: streamToken,
    user_id: userId,
    call_type: CALL_TYPE,
    call_id: callIdFor(squadId),
    expires_at: new Date(claims.exp * 1000).toISOString(),
  });
}
