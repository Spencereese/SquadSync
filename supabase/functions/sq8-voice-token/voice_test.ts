import { assert, assertEquals } from "jsr:@std/assert@1";
import { CALL_TYPE, callIdFor, claimsFor, type Deps, handle, missingStreamSecrets, signStreamToken, TOKEN_TTL_SECONDS } from "./voice.ts";

const SQUAD = "11111111-2222-4333-8444-555555555555";
const USER = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
const NOW = 1_800_000_000;
// Test-only values; nothing real.
const TEST_SECRET = "test-secret-not-real";
const TEST_KEY = "testkey";

type Seen = { url: string; auth: string | null }[];

function deps(options: {
  env?: Record<string, string | undefined>;
  user?: string | null;
  rows?: unknown;
  rowsStatus?: number;
  seen?: Seen;
}): Deps {
  const env: Record<string, string | undefined> = {
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_ANON_KEY: "anon",
    STREAM_API_KEY: TEST_KEY,
    STREAM_API_SECRET: TEST_SECRET,
    ...options.env,
  };
  return {
    env: (name) => env[name],
    now: () => NOW,
    fetch: (input, init) => {
      const headers = new Headers(init?.headers);
      options.seen?.push({ url: input, auth: headers.get("Authorization") });
      if (input.endsWith("/auth/v1/user")) {
        const user = options.user === undefined ? USER : options.user;
        return Promise.resolve(
          user ? Response.json({ id: user }) : Response.json({ msg: "invalid JWT" }, { status: 401 }),
        );
      }
      if (input.includes("/rest/v1/sq8_squad_members?")) {
        return Promise.resolve(Response.json(options.rows ?? [{ user_id: USER }], { status: options.rowsStatus ?? 200 }));
      }
      return Promise.resolve(new Response("unexpected", { status: 500 }));
    },
  };
}

function post(body: unknown = { squad_id: SQUAD }, auth: string | null = "Bearer user-jwt"): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (auth) headers.Authorization = auth;
  return new Request("https://fn.test/sq8-voice-token", { method: "POST", headers, body: JSON.stringify(body) });
}

function decode(part: string): Record<string, unknown> {
  const padded = part.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((part.length + 3) % 4);
  return JSON.parse(atob(padded));
}

Deno.test("no Authorization header: 401 and nothing is fetched", async () => {
  const seen: Seen = [];
  const response = await handle(post(undefined, null), deps({ seen }));
  assertEquals(response.status, 401);
  assertEquals(await response.json(), { ok: false, reason: "signed_out" });
  assertEquals(seen.length, 0);
});

Deno.test("a session Supabase Auth rejects: 401", async () => {
  const response = await handle(post(), deps({ user: null }));
  assertEquals(response.status, 401);
  assertEquals((await response.json()).reason, "signed_out");
});

Deno.test("the Stream secrets missing: 503 voice_not_configured, no token, no membership read", async () => {
  for (const env of [
    { STREAM_API_KEY: undefined, STREAM_API_SECRET: undefined },
    { STREAM_API_SECRET: undefined },
    { STREAM_API_KEY: "  " },
  ]) {
    const seen: Seen = [];
    const response = await handle(post(), deps({ env, seen }));
    assertEquals(response.status, 503);
    const body = await response.json();
    assertEquals(body, { ok: false, reason: "voice_not_configured" });
    assertEquals("token" in body, false);
    assertEquals(seen.some((s) => s.url.includes("sq8_squad_members")), false);
  }
});

Deno.test("missingStreamSecrets names only what is missing", () => {
  assertEquals(missingStreamSecrets(() => undefined), ["STREAM_API_KEY", "STREAM_API_SECRET"]);
  assertEquals(missingStreamSecrets((n) => (n === "STREAM_API_KEY" ? "k" : undefined)), ["STREAM_API_SECRET"]);
});

Deno.test("a squad id that isn't a uuid: 400", async () => {
  for (const body of [{}, { squad_id: "abc" }, { squad_id: 42 }]) {
    const response = await handle(post(body), deps({}));
    assertEquals(response.status, 400);
  }
});

Deno.test("not in the squad: 403, read with the caller's own token (row level security)", async () => {
  const seen: Seen = [];
  const response = await handle(post(), deps({ rows: [], seen }));
  assertEquals(response.status, 403);
  assertEquals((await response.json()).reason, "not_a_member");
  const read = seen.find((s) => s.url.includes("sq8_squad_members"))!;
  assertEquals(read.auth, "Bearer user-jwt");
  assert(read.url.includes(`squad_id=eq.${SQUAD}`) && read.url.includes(`user_id=eq.${USER}`));
});

Deno.test("membership can't be read: 502, never a token", async () => {
  const response = await handle(post(), deps({ rowsStatus: 500, rows: { message: "boom" } }));
  assertEquals(response.status, 502);
  assertEquals("token" in (await response.json()), false);
});

Deno.test("a member gets a call token for exactly this squad's room", async () => {
  const response = await handle(post(), deps({}));
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.ok, true);
  assertEquals(body.api_key, TEST_KEY);
  assertEquals(body.user_id, USER);
  assertEquals(body.call_type, CALL_TYPE);
  assertEquals(body.call_id, `sq8-${SQUAD}`);
  assertEquals(body.expires_at, new Date((NOW + TOKEN_TTL_SECONDS) * 1000).toISOString());
  const [head, claims, signature] = body.token.split(".");
  assertEquals(decode(head), { alg: "HS256", typ: "JWT" });
  const payload = decode(claims);
  assertEquals(payload.user_id, USER);
  assertEquals(payload.call_cids, [`default:sq8-${SQUAD}`]);
  assertEquals(payload.exp, NOW + TOKEN_TTL_SECONDS);
  assert((payload.iat as number) <= NOW);
  assert(signature.length > 20);
  assertEquals(JSON.stringify(body).includes(TEST_SECRET), false, "the secret never leaves");
});

Deno.test("the signature is HS256 over header.payload with the secret", async () => {
  const claims = claimsFor(USER, SQUAD, NOW);
  const token = await signStreamToken(claims, TEST_SECRET);
  const [head, body, signature] = token.split(".");
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(TEST_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
  const raw = Uint8Array.from(atob(signature.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((signature.length + 3) % 4)), (c) => c.charCodeAt(0));
  assert(await crypto.subtle.verify("HMAC", key, raw, new TextEncoder().encode(`${head}.${body}`)));
  const other = await signStreamToken(claims, "another-secret");
  assert(other !== token);
});

Deno.test("only POST", async () => {
  const response = await handle(new Request("https://fn.test/x", { method: "GET" }), deps({}));
  assertEquals(response.status, 405);
});

Deno.test("call ids are lowercase and inside Stream's limits", () => {
  const id = callIdFor(SQUAD.toUpperCase());
  assertEquals(id, `sq8-${SQUAD}`);
  assert(/^[a-z0-9_-]{1,64}$/.test(id));
});
