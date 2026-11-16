// APNs alert body for a raw device token. Signing uses the .p8 only when
// the caller passes it. This file does not read the environment itself.

import { pemToPkcs8 } from "./fcm.ts";

export const apnsSandboxHost = "https://api.sandbox.push.apple.com";
export const apnsProductionHost = "https://api.push.apple.com";

export function apnsHost(sandbox: boolean): string {
  return sandbox ? apnsSandboxHost : apnsProductionHost;
}

export function missingApnsSecrets(env: Record<string, string | undefined>): string[] {
  return ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID", "APNS_BUNDLE_ID"].filter(
    (name) => !env[name],
  );
}

/// The same fields the iOS app parses from a tap, including a cold launch.
export function buildApnsPayload(input: {
  squadId: string;
  messageId?: string;
  kind?: "squad_message" | "squad";
}): Record<string, unknown> {
  const type = input.kind ?? "squad_message";
  const payload: Record<string, unknown> = {
    aps: {
      alert: {
        title: "SquadSync",
        body: type === "squad" ? "Open squad" : "New message",
      },
      "thread-id": `squad:${input.squadId}`,
      sound: "default",
    },
    type,
    squad_id: input.squadId,
  };
  if (type === "squad_message" && input.messageId) {
    payload.message_id = input.messageId;
  }
  return payload;
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

/// Bearer for `api.push.apple.com`. Returns null when the key is missing.
export async function apnsAuthorization(input: {
  keyPem: string;
  keyId: string;
  teamId: string;
  nowSeconds: number;
}): Promise<string | null> {
  if (!input.keyPem || !input.keyId || !input.teamId) return null;
  const header = base64url(new TextEncoder().encode(JSON.stringify({
    alg: "ES256",
    kid: input.keyId,
  })));
  const claims = base64url(new TextEncoder().encode(JSON.stringify({
    iss: input.teamId,
    iat: input.nowSeconds,
  })));
  const signingInput = `${header}.${claims}`;
  const pkcs8 = pemToPkcs8(input.keyPem);
  const keyBytes = new ArrayBuffer(pkcs8.byteLength);
  new Uint8Array(keyBytes).set(pkcs8);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(signingInput),
    ),
  );
  return `${signingInput}.${base64url(signature)}`;
}
