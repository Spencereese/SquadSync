// Not deployed. Sends nothing until Spencer sets the secrets named in README.md.
// A new sq8_messages row notifies the other current members of that squad.
// Recipients come from sq8.message_push_targets, which drops the sender.
// This function uses the service role, so it must not trust a client-supplied
// recipient list.

const cors = {
  "content-type": "application/json",
};

type MessageRecord = {
  id?: string;
  squad_id?: string;
  sender_id?: string;
};

function missingSecrets(): string[] {
  const names = [
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "SQ8_PUSH_WEBHOOK_SECRET",
    "FCM_SERVER_KEY",
  ];
  return names.filter((name) => !Deno.env.get(name));
}

function readRecord(body: unknown): MessageRecord | null {
  if (!body || typeof body !== "object") return null;
  const record = (body as { record?: unknown }).record;
  if (!record || typeof record !== "object") return null;
  const row = record as MessageRecord;
  if (!row.id || !row.squad_id || !row.sender_id) return null;
  return row;
}

Deno.serve(async (request) => {
  const missing = missingSecrets();
  if (missing.length > 0) {
    return new Response(
      JSON.stringify({
        ok: false,
        reason: "notifications off",
        missing,
      }),
      { status: 200, headers: cors },
    );
  }

  const expected = Deno.env.get("SQ8_PUSH_WEBHOOK_SECRET");
  const provided = request.headers.get("x-sq8-webhook-secret");
  if (!expected || provided !== expected) {
    return new Response(JSON.stringify({ ok: false, reason: "unauthorized" }), {
      status: 401,
      headers: cors,
    });
  }

  const record = readRecord(await request.json().catch(() => null));
  if (!record) {
    return new Response(JSON.stringify({ ok: false, reason: "bad payload" }), {
      status: 400,
      headers: cors,
    });
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const targets = await fetch(`${url}/rest/v1/rpc/sq8_message_push_targets`, {
    method: "POST",
    headers: {
      apikey: key,
      authorization: `Bearer ${key}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      squad: record.squad_id,
      sender: record.sender_id,
    }),
  });
  if (!targets.ok) {
    return new Response(
      JSON.stringify({ ok: false, reason: "target lookup failed" }),
      { status: 502, headers: cors },
    );
  }
  const rows = (await targets.json()) as Array<{
    token: string;
    platform: string;
  }>;

  // FCM is the only sender stubbed here. APNs is reached through FCM on iOS
  // once Spencer uploads the APNs key to Firebase. No key is stored in git.
  const fcm = Deno.env.get("FCM_SERVER_KEY")!;
  let sent = 0;
  for (const row of rows) {
    const response = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        authorization: `key=${fcm}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        to: row.token,
        data: {
          type: "squad_message",
          squad_id: record.squad_id,
          message_id: record.id,
        },
      }),
    });
    if (response.ok) sent += 1;
  }

  return new Response(JSON.stringify({ ok: true, sent }), {
    status: 200,
    headers: cors,
  });
});
