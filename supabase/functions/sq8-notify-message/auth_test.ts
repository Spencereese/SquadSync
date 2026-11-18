import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { unauthorizedResponse, webhookAuthorized } from "./auth.ts";

Deno.test("only the exact secret is authorized", () => {
  assertEquals(webhookAuthorized("s3cret", "s3cret"), true);
  assertEquals(webhookAuthorized("s3cret", "s3cre"), false);
  assertEquals(webhookAuthorized("s3cret", "s3cret!"), false);
  assertEquals(webhookAuthorized("s3cret", "S3cret"), false);
});

Deno.test("a missing header or an unset secret is never authorized", () => {
  assertEquals(webhookAuthorized("s3cret", null), false);
  assertEquals(webhookAuthorized("s3cret", ""), false);
  assertEquals(webhookAuthorized(undefined, "anything"), false);
  assertEquals(webhookAuthorized("", ""), false);
  assertEquals(webhookAuthorized(undefined, undefined), false);
});

Deno.test("the refusal is a 401 that names no secrets", async () => {
  const response = unauthorizedResponse({ "content-type": "application/json" });
  assertEquals(response.status, 401);
  const body = await response.json();
  assertEquals(body, { ok: false, reason: "unauthorized" });
});

Deno.test("index.ts checks the secret before the notifications-off reply", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  const serve = source.indexOf("Deno.serve(");
  const auth = source.indexOf("webhookAuthorized(", serve);
  const off = source.indexOf('"notifications off"', serve);
  const body = source.indexOf("request.json()", serve);
  assertEquals(serve > 0, true);
  assertEquals(auth > serve, true, "the check is inside the handler");
  assertEquals(auth < off, true, "401 comes before the notifications-off reply");
  assertEquals(auth < body, true, "401 comes before reading the body");
  assertEquals(source.includes('provided !== expected'), false, "the old late check is gone");
});

Deno.test("the real handler: no header gets 401 even with every secret unset", async () => {
  let handler: ((request: Request) => Promise<Response>) | null = null;
  const original = Deno.serve;
  // deno-lint-ignore no-explicit-any
  (Deno as any).serve = (h: (request: Request) => Promise<Response>) => {
    handler = h;
    return { finished: Promise.resolve(), shutdown: async () => {} };
  };
  try {
    await import("./index.ts");
  } finally {
    // deno-lint-ignore no-explicit-any
    (Deno as any).serve = original;
  }
  if (!handler) throw new Error("index.ts did not register a handler");
  const serve = handler as (request: Request) => Promise<Response>;
  const saved = Deno.env.get("SQ8_PUSH_WEBHOOK_SECRET");
  Deno.env.delete("SQ8_PUSH_WEBHOOK_SECRET");
  try {
    const bare = await serve(new Request("http://local/", { method: "POST", body: "{}" }));
    assertEquals(bare.status, 401);
    const text = await bare.text();
    assertEquals(text.includes("missing"), false, "no list of unset secrets");
    assertEquals(text.includes("notifications off"), false);

    Deno.env.set("SQ8_PUSH_WEBHOOK_SECRET", "s3cret");
    const wrong = await serve(new Request("http://local/", {
      method: "POST",
      headers: { "x-sq8-webhook-secret": "nope" },
      body: "{}",
    }));
    assertEquals(wrong.status, 401);
    await wrong.body?.cancel();

    const right = await serve(new Request("http://local/", {
      method: "POST",
      headers: { "x-sq8-webhook-secret": "s3cret" },
      body: "{}",
    }));
    assertEquals(right.status, 200, "past the check, the other secrets are unset: notifications off");
    assertEquals((await right.json()).reason, "notifications off");
  } finally {
    if (saved === undefined) Deno.env.delete("SQ8_PUSH_WEBHOOK_SECRET");
    else Deno.env.set("SQ8_PUSH_WEBHOOK_SECRET", saved);
  }
});
