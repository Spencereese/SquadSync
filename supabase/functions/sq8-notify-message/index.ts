// Not deployed. Sends nothing until Spencer sets the secrets named in README.md.
// A new sq8_messages row notifies the other current members of that squad.
// Recipients come from sq8.message_push_targets, which drops the sender.
// This function uses the service role, so it must not trust a client-supplied
// recipient list. FCM is HTTP v1 with a service-account JWT, not the legacy
// server key.

import { apnsAuthorization, apnsHost, buildApnsPayload, missingApnsSecrets } from "./apns.ts";
import {
  AccessTokenCache,
  type ServiceAccount,
  buildSquadMessage,
  jwtSigningInput,
  pemToPkcs8,
  tokenShouldBeDropped,
} from "./fcm.ts";

const cors = { "content-type": "application/json" };
const cache = new AccessTokenCache();

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
    "FCM_SERVICE_ACCOUNT_JSON",
  ];
  return names.filter((name) => !Deno.env.get(name));
}

function readAccount(): ServiceAccount | null {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as Partial<ServiceAccount>;
    if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
      return null;
    }
    return {
      client_email: parsed.client_email,
      private_key: parsed.private_key,
      project_id: parsed.project_id,
    };
  } catch {
    return null;
  }
}

function readRecord(body: unknown): MessageRecord | null {
  if (!body || typeof body !== "object") return null;
  const record = (body as { record?: unknown }).record;
  if (!record || typeof record !== "object") return null;
  const row = record as MessageRecord;
  if (!row.id || !row.squad_id || !row.sender_id) return null;
  return row;
}

async function signServiceJwt(account: ServiceAccount, nowSeconds: number): Promise<string> {
  const signingInput = jwtSigningInput(account, nowSeconds);
  const pkcs8 = pemToPkcs8(account.private_key);
  const keyBytes = new ArrayBuffer(pkcs8.byteLength);
  new Uint8Array(keyBytes).set(pkcs8);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(signingInput),
    ),
  );
  let binary = "";
  for (const byte of signature) binary += String.fromCharCode(byte);
  const encoded = btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
  return `${signingInput}.${encoded}`;
}

async function accessToken(account: ServiceAccount): Promise<string | null> {
  const now = Math.floor(Date.now() / 1000);
  const cached = cache.get(now);
  if (cached) return cached;
  const assertion = await signServiceJwt(account, now);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) return null;
  const minted = await response.json() as { access_token?: string; expires_in?: number };
  if (!minted.access_token) return null;
  const lifetime = minted.expires_in ?? 3600;
  cache.set(minted.access_token, now + lifetime);
  return minted.access_token;
}

Deno.serve(async (request) => {
  const requiredMissing = missingSecrets().filter((name) =>
    name !== "FCM_SERVICE_ACCOUNT_JSON"
  );
  const account = readAccount();
  const apnsEnv = {
    APNS_KEY_P8: Deno.env.get("APNS_KEY_P8"),
    APNS_KEY_ID: Deno.env.get("APNS_KEY_ID"),
    APNS_TEAM_ID: Deno.env.get("APNS_TEAM_ID"),
    APNS_BUNDLE_ID: Deno.env.get("APNS_BUNDLE_ID"),
  };
  const apnsMissing = missingApnsSecrets(apnsEnv);
  if (requiredMissing.length > 0 || (!account && apnsMissing.length > 0)) {
    return new Response(
      JSON.stringify({
        ok: false,
        reason: "notifications off",
        missing: [
          ...requiredMissing,
          ...(account ? [] : ["FCM_SERVICE_ACCOUNT_JSON"]),
          ...apnsMissing,
        ],
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
    body: JSON.stringify({ squad: record.squad_id, sender: record.sender_id }),
  });
  if (!targets.ok) {
    return new Response(
      JSON.stringify({ ok: false, reason: "target lookup failed" }),
      { status: 502, headers: cors },
    );
  }
  const rows = await targets.json() as Array<{ token: string; platform: string }>;
  const bearer = account ? await accessToken(account) : null;
  let apnsBearer: string | null = null;
  if (apnsMissing.length === 0) {
    try {
      apnsBearer = await apnsAuthorization({
        keyPem: apnsEnv.APNS_KEY_P8 ?? "",
        keyId: apnsEnv.APNS_KEY_ID ?? "",
        teamId: apnsEnv.APNS_TEAM_ID ?? "",
        nowSeconds: Math.floor(Date.now() / 1000),
      });
    } catch {
      apnsBearer = null;
    }
  }

  let sent = 0;
  let dropped = 0;
  let skipped = 0;
  for (const row of rows) {
    if (row.platform === "ios") {
      if (!apnsBearer || !apnsEnv.APNS_BUNDLE_ID) {
        skipped += 1;
        continue;
      }
      const response = await fetch(
        `${apnsHost(Deno.env.get("APNS_SANDBOX") !== "false")}/3/device/${row.token}`,
        {
          method: "POST",
          headers: {
            authorization: `bearer ${apnsBearer}`,
            "apns-topic": apnsEnv.APNS_BUNDLE_ID,
            "apns-push-type": "alert",
            "apns-priority": "10",
            "content-type": "application/json",
          },
          body: JSON.stringify(buildApnsPayload({
            squadId: record.squad_id!,
            messageId: record.id!,
          })),
        },
      );
      if (response.ok) sent += 1;
      else if (response.status === 410) {
        const removed = await fetch(`${url}/rest/v1/rpc/sq8_drop_device_token`, {
          method: "POST",
          headers: {
            apikey: key,
            authorization: `Bearer ${key}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({ device_token: row.token }),
        });
        if (removed.ok) dropped += 1;
      }
      continue;
    }
    if (!bearer || !account) {
      skipped += 1;
      continue;
    }
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${bearer}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(buildSquadMessage({
          token: row.token,
          squadId: record.squad_id!,
          messageId: record.id!,
        })),
      },
    );
    if (response.ok) {
      sent += 1;
      continue;
    }
    const failure = await response.json().catch(() => null);
    if (!tokenShouldBeDropped(failure)) continue;
    const removed = await fetch(`${url}/rest/v1/rpc/sq8_drop_device_token`, {
      method: "POST",
      headers: {
        apikey: key,
        authorization: `Bearer ${key}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ device_token: row.token }),
    });
    if (removed.ok) dropped += 1;
  }

  return new Response(JSON.stringify({
    ok: true,
    sent,
    dropped,
    skipped,
    apns: apnsMissing.length === 0 ? "ready" : "key missing",
  }), {
    status: 200,
    headers: cors,
  });
});
