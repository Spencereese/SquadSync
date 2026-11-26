// Drives the real handler with fetch stubbed: which RPC it asks, and what it
// sends to APNs and FCM, for a squad message and for a side-thread reply.
// No network. Keys are generated here and thrown away.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

type Call = { url: string; headers: Record<string, string>; body: unknown };

function toPem(der: ArrayBuffer): string {
  let binary = "";
  for (const byte of new Uint8Array(der)) binary += String.fromCharCode(byte);
  return `-----BEGIN PRIVATE KEY-----\n${btoa(binary)}\n-----END PRIVATE KEY-----`;
}

async function keys(): Promise<{ apns: string; fcm: string }> {
  const ec = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign"]);
  const rsa = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign"],
  );
  return {
    apns: toPem(await crypto.subtle.exportKey("pkcs8", ec.privateKey)),
    fcm: toPem(await crypto.subtle.exportKey("pkcs8", rsa.privateKey)),
  };
}

let handler: ((request: Request) => Promise<Response>) | null = null;

async function loadHandler(): Promise<(request: Request) => Promise<Response>> {
  if (handler) return handler;
  const original = Deno.serve;
  // deno-lint-ignore no-explicit-any
  (Deno as any).serve = (h: (request: Request) => Promise<Response>) => {
    handler = h;
    return { finished: Promise.resolve(), shutdown: async () => {} };
  };
  try {
    // Its own module instance, so auth_test.ts's import doesn't share it.
    await import("./index.ts?handler-test");
  } finally {
    // deno-lint-ignore no-explicit-any
    (Deno as any).serve = original;
  }
  if (!handler) throw new Error("index.ts did not register a handler");
  return handler;
}

const envNames = [
  "SQ8_PUSH_WEBHOOK_SECRET",
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "FCM_SERVICE_ACCOUNT_JSON",
  "APNS_KEY_P8",
  "APNS_KEY_ID",
  "APNS_TEAM_ID",
  "APNS_BUNDLE_ID",
  "APNS_SANDBOX",
];

async function run(
  webhook: unknown,
  respond: (call: Call) => Response,
): Promise<{ status: number; result: Record<string, unknown>; calls: Call[] }> {
  const serve = await loadHandler();
  const { apns, fcm } = await keys();
  const saved = new Map(envNames.map((name) => [name, Deno.env.get(name)]));
  Deno.env.set("SQ8_PUSH_WEBHOOK_SECRET", "s3cret");
  Deno.env.set("SUPABASE_URL", "https://project.example");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-key");
  Deno.env.set("FCM_SERVICE_ACCOUNT_JSON", JSON.stringify({
    client_email: "push@squadsync.iam.gserviceaccount.com",
    private_key: fcm,
    project_id: "squadsync-dev",
  }));
  Deno.env.set("APNS_KEY_P8", apns);
  Deno.env.set("APNS_KEY_ID", "KEYID12345");
  Deno.env.set("APNS_TEAM_ID", "K4ZTXPQ8J9");
  Deno.env.set("APNS_BUNDLE_ID", "com.spencereese.squadsync");
  Deno.env.delete("APNS_SANDBOX");
  const calls: Call[] = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = input instanceof Request ? input.url : String(input);
    const headers: Record<string, string> = {};
    new Headers(init?.headers).forEach((value, name) => headers[name] = value);
    let body: unknown = init?.body ?? null;
    if (typeof body === "string") {
      try {
        body = JSON.parse(body);
      } catch {
        // form body (the OAuth token request) stays text
      }
    } else if (body instanceof URLSearchParams) {
      body = body.toString();
    }
    const call = { url, headers, body };
    calls.push(call);
    return respond(call);
  }) as typeof fetch;
  try {
    const response = await serve(new Request("http://local/", {
      method: "POST",
      headers: { "x-sq8-webhook-secret": "s3cret", "content-type": "application/json" },
      body: JSON.stringify(webhook),
    }));
    return { status: response.status, result: await response.json(), calls };
  } finally {
    globalThis.fetch = realFetch;
    for (const [name, value] of saved) {
      if (value === undefined) Deno.env.delete(name);
      else Deno.env.set(name, value);
    }
  }
}

const json = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), { status, headers: { "content-type": "application/json" } });

function standardRespond(rows: Array<{ token: string; platform: string }>, context: unknown[]) {
  return (call: Call): Response => {
    if (call.url.endsWith("/rpc/sq8_message_push_targets")) return json(rows);
    if (call.url.endsWith("/rpc/sq8_thread_push_targets")) return json(rows);
    if (call.url.endsWith("/rpc/sq8_thread_push_context")) return json(context);
    if (call.url === "https://oauth2.googleapis.com/token") {
      return json({ access_token: "fcm-access", expires_in: 3600 });
    }
    if (call.url.includes("/3/device/")) return new Response(null, { status: 200 });
    if (call.url.includes("fcm.googleapis.com")) return json({ name: "projects/x/messages/1" });
    return new Response("unexpected", { status: 500 });
  };
}

const squad = "00000000-0000-0000-0000-000000000010";
const thread = "00000000-0000-0000-0000-00000000b001";
const reply = "00000000-0000-0000-0000-00000000b103";
const sender = "00000000-0000-0000-0000-000000000002";

Deno.test("a squad message keeps its old targets and payload", async () => {
  const { status, result, calls } = await run(
    {
      type: "INSERT",
      table: "sq8_messages",
      schema: "public",
      record: { id: "00000000-0000-0000-0000-00000000a001", squad_id: squad, sender_id: sender, body: "gg" },
    },
    standardRespond([{ token: "ios-token", platform: "ios" }], []),
  );
  assertEquals(status, 200);
  assertEquals(result.sent, 1);
  const rpcs = calls.filter((call) => call.url.includes("/rest/v1/rpc/"));
  assertEquals(rpcs.map((call) => call.url.split("/rpc/")[1]), ["sq8_message_push_targets"]);
  assertEquals(rpcs[0].body, { squad, sender });
  const apns = calls.find((call) => call.url.includes("/3/device/"))!;
  assertEquals(apns.url, "https://api.sandbox.push.apple.com/3/device/ios-token");
  assertEquals(apns.headers["apns-collapse-id"], undefined, "the squad path sends no collapse header, as before");
  assertEquals(apns.body, {
    aps: {
      alert: { title: "SquadSync", body: "New message" },
      "thread-id": `squad:${squad}`,
      sound: "default",
    },
    type: "squad_message",
    squad_id: squad,
    message_id: "00000000-0000-0000-0000-00000000a001",
  });
});

Deno.test("a body with no table still takes the squad path", async () => {
  const { status, calls } = await run(
    { record: { id: "00000000-0000-0000-0000-00000000a001", squad_id: squad, sender_id: sender } },
    standardRespond([], []),
  );
  assertEquals(status, 200);
  assertEquals(calls.map((call) => call.url.split("/rpc/")[1]), ["sq8_message_push_targets"]);
});

Deno.test("a side-thread reply asks for that thread's targets and sends by thread", async () => {
  const { status, result, calls } = await run(
    {
      type: "INSERT",
      table: "sq8_thread_messages",
      schema: "public",
      record: { id: reply, thread_id: thread, squad_id: squad, sender_id: sender, body: "  on in 5,\n bring the\tmic  ", sent_at: "2026-11-26T09:00:00Z" },
    },
    standardRespond(
      [{ token: "ios-token", platform: "ios" }, { token: "android-token", platform: "android" }],
      [{ thread_kind: "side_group", thread_title: "Ranked", sender_name: "Riley" }],
    ),
  );
  assertEquals(status, 200);
  assertEquals(result.sent, 2);
  const rpcs = calls.filter((call) => call.url.includes("/rest/v1/rpc/"));
  assertEquals(rpcs.map((call) => call.url.split("/rpc/")[1]), ["sq8_thread_push_targets", "sq8_thread_push_context"]);
  assertEquals(rpcs[0].body, { thread, sender });
  assertEquals(rpcs[0].headers.authorization, "Bearer service-key");
  assertEquals(calls.some((call) => call.url.endsWith("sq8_message_push_targets")), false, "the squad isn't notified");

  const apns = calls.find((call) => call.url.includes("/3/device/"))!;
  assertEquals(apns.url, "https://api.sandbox.push.apple.com/3/device/ios-token");
  assertEquals(apns.headers["apns-collapse-id"], `thread:${thread}`);
  assertEquals(apns.headers["apns-topic"], "com.spencereese.squadsync");
  assertEquals(apns.headers["apns-push-type"], "alert");
  assertEquals(apns.body, {
    aps: {
      alert: { title: "Riley in Ranked", body: "on in 5, bring the mic" },
      "thread-id": `thread:${thread}`,
      sound: "default",
    },
    type: "thread_message",
    squad_id: squad,
    thread_id: thread,
    message_id: reply,
  });

  const fcm = calls.find((call) => call.url.includes("fcm.googleapis.com"))!;
  const message = (fcm.body as { message: Record<string, unknown> }).message;
  assertEquals(message.token, "android-token");
  assertEquals(message.data, { type: "thread_message", squad_id: squad, thread_id: thread, message_id: reply });
  assertEquals((message.android as { collapse_key: string }).collapse_key, `thread:${thread}`);
  assertEquals(message.notification, { title: "Riley in Ranked", body: "on in 5, bring the mic" });
});

Deno.test("no targets: no context read and nothing sent", async () => {
  const { status, result, calls } = await run(
    { table: "sq8_thread_messages", schema: "public", record: { id: reply, thread_id: thread, squad_id: squad, sender_id: sender, body: "hi" } },
    standardRespond([], []),
  );
  assertEquals(status, 200);
  assertEquals(result.sent, 0);
  assertEquals(calls.map((call) => call.url.split("/rpc/")[1]), ["sq8_thread_push_targets"]);
});

Deno.test("a failed context read still sends, with plain wording", async () => {
  const { result, calls } = await run(
    { table: "sq8_thread_messages", schema: "public", record: { id: reply, thread_id: thread, squad_id: squad, sender_id: sender, body: "hi" } },
    (call) => {
      if (call.url.endsWith("/rpc/sq8_thread_push_context")) return new Response("nope", { status: 500 });
      return standardRespond([{ token: "ios-token", platform: "ios" }], [])(call);
    },
  );
  assertEquals(result.sent, 1);
  const apns = calls.find((call) => call.url.includes("/3/device/"))!;
  const aps = (apns.body as { aps: { alert: { title: string; body: string } } }).aps;
  assertEquals(aps.alert, { title: "Someone in a side thread", body: "hi" });
});

Deno.test("a thread body missing its thread id is a 400 and sends nothing", async () => {
  const { status, result, calls } = await run(
    { table: "sq8_thread_messages", schema: "public", record: { id: reply, squad_id: squad, sender_id: sender, body: "hi" } },
    standardRespond([{ token: "ios-token", platform: "ios" }], []),
  );
  assertEquals(status, 400);
  assertEquals(result.reason, "bad payload");
  assertEquals(calls.length, 0);
});

Deno.test("a dead APNs token from a thread push is dropped", async () => {
  const { result, calls } = await run(
    { table: "sq8_thread_messages", schema: "public", record: { id: reply, thread_id: thread, squad_id: squad, sender_id: sender, body: "hi" } },
    (call) => {
      if (call.url.includes("/3/device/")) return new Response(null, { status: 410 });
      if (call.url.endsWith("/rpc/sq8_drop_device_token")) return new Response(null, { status: 204 });
      return standardRespond([{ token: "gone-token", platform: "ios" }], [])(call);
    },
  );
  assertEquals(result.dropped, 1);
  const drop = calls.find((call) => call.url.endsWith("/rpc/sq8_drop_device_token"))!;
  assertEquals(drop.body, { device_token: "gone-token" });
});

const gameOnCall = "00000000-0000-0000-0000-00000000c001";

Deno.test("a Game on asks the group's targets and its context, and sends the banner", async () => {
  const { status, result, calls } = await run(
    {
      type: "INSERT",
      table: "sq8_spot_calls",
      schema: "public",
      record: { id: gameOnCall, squad_id: squad, caller_id: sender, kind: "game_on", game: "Warzone", seat_target: 2, status: "open" },
    },
    (call) => {
      if (call.url.endsWith("/rpc/sq8_game_on_push_context")) {
        return json([{ caller_name: "Riley", game: "Warzone", need: 1, kind: "game_on" }]);
      }
      return standardRespond([{ token: "ios-token", platform: "ios" }, { token: "android-token", platform: "android" }], [])(call);
    },
  );
  assertEquals(status, 200);
  assertEquals(result.sent, 2);
  const rpcs = calls.filter((call) => call.url.includes("/rest/v1/rpc/"));
  assertEquals(rpcs.map((call) => call.url.split("/rpc/")[1]), ["sq8_message_push_targets", "sq8_game_on_push_context"]);
  assertEquals(rpcs[0].body, { squad, sender }, "the starter is left out");
  assertEquals(rpcs[1].body, { call_id: gameOnCall });
  const apns = calls.find((call) => call.url.includes("/3/device/"))!;
  assertEquals(apns.headers["apns-collapse-id"], `game_on:${gameOnCall}`);
  assertEquals(apns.body, {
    aps: {
      alert: { title: "Game on", body: "Riley's on Warzone, need 1" },
      "thread-id": `squad:${squad}`,
      sound: "default",
    },
    type: "game_on",
    squad_id: squad,
    call_id: gameOnCall,
  });
  const fcm = calls.find((call) => call.url.includes("fcm.googleapis.com"))!;
  const message = (fcm.body as { message: Record<string, unknown> }).message;
  assertEquals(message.data, { type: "game_on", squad_id: squad, call_id: gameOnCall });
});

Deno.test("an old build's spot call sends nothing and reads nothing", async () => {
  const { status, result, calls } = await run(
    {
      type: "INSERT",
      table: "sq8_spot_calls",
      schema: "public",
      record: { id: gameOnCall, squad_id: squad, caller_id: sender, kind: "spot", game: "Halo" },
    },
    standardRespond([{ token: "ios-token", platform: "ios" }], []),
  );
  assertEquals(status, 200);
  assertEquals(result.sent, 0);
  assertEquals(calls.length, 0);
});

Deno.test("a Game on body missing its caller is a 400", async () => {
  const { status, calls } = await run(
    { type: "INSERT", table: "sq8_spot_calls", schema: "public", record: { id: gameOnCall, squad_id: squad, kind: "game_on" } },
    standardRespond([{ token: "ios-token", platform: "ios" }], []),
  );
  assertEquals(status, 400);
  assertEquals(calls.length, 0);
});

Deno.test("a failed Game on context read still sends, from the row", async () => {
  const { result, calls } = await run(
    { type: "INSERT", table: "sq8_spot_calls", schema: "public", record: { id: gameOnCall, squad_id: squad, caller_id: sender, kind: "game_on", game: "Apex", seat_target: 4 } },
    (call) => {
      if (call.url.endsWith("/rpc/sq8_game_on_push_context")) return new Response("nope", { status: 500 });
      return standardRespond([{ token: "ios-token", platform: "ios" }], [])(call);
    },
  );
  assertEquals(result.sent, 1);
  const apns = calls.find((call) => call.url.includes("/3/device/"))!;
  const aps = (apns.body as { aps: { alert: { title: string; body: string } } }).aps;
  assertEquals(aps.alert, { title: "Game on", body: "Someone's on Apex, need 3" });
});
