// Pure FCM HTTP v1 helpers. No network. The function is not deployed.

export const messagingScope = "https://www.googleapis.com/auth/firebase.messaging";
export const tokenAudience = "https://oauth2.googleapis.com/token";

export type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
};

export function buildMessagingClaims(
  account: Pick<ServiceAccount, "client_email">,
  nowSeconds: number,
): Record<string, string | number> {
  return {
    iss: account.client_email,
    scope: messagingScope,
    aud: tokenAudience,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  };
}

export function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

export function encodeJson(value: unknown): string {
  return bytesToBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

/** The unsigned `header.payload` that Web Crypto signs. */
export function jwtSigningInput(
  account: Pick<ServiceAccount, "client_email">,
  nowSeconds: number,
): string {
  const header = encodeJson({ alg: "RS256", typ: "JWT" });
  const payload = encodeJson(buildMessagingClaims(account, nowSeconds));
  return `${header}.${payload}`;
}

export function squadThreadId(squadId: string): string {
  return `squad:${squadId}`;
}

/// Data-only fields ride in `data` and again beside `aps`, so an iOS tap
/// still has the squad id when the app was not running. Android and APNs
/// collapse and thread by squad.
export function buildSquadMessage(input: {
  token: string;
  squadId: string;
  messageId: string;
}): { message: Record<string, unknown> } {
  const thread = squadThreadId(input.squadId);
  const data = {
    type: "squad_message",
    squad_id: input.squadId,
    message_id: input.messageId,
  };
  return {
    message: {
      token: input.token,
      data,
      notification: { title: "SquadSync", body: "New message" },
      android: {
        collapse_key: thread,
        priority: "HIGH",
        notification: { tag: thread },
      },
      apns: {
        headers: {
          "apns-collapse-id": thread,
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: { title: "SquadSync", body: "New message" },
            "thread-id": thread,
            sound: "default",
          },
          type: data.type,
          squad_id: data.squad_id,
          message_id: data.message_id,
        },
      },
    },
  };
}

type FcmError = {
  status?: string;
  details?: Array<{ errorCode?: string }>;
};

/// FCM HTTP v1 reports a dead install as UNREGISTERED or INVALID_ARGUMENT.
export function tokenShouldBeDropped(body: unknown): boolean {
  if (!body || typeof body !== "object") return false;
  const error = (body as { error?: FcmError }).error;
  if (!error) return false;
  const codes = new Set<string>();
  if (error.status) codes.add(error.status);
  for (const detail of error.details ?? []) {
    if (detail.errorCode) codes.add(detail.errorCode);
  }
  return codes.has("UNREGISTERED") || codes.has("INVALID_ARGUMENT");
}

export class AccessTokenCache {
  #token: string | null = null;
  #exp = 0;

  get(nowSeconds: number): string | null {
    if (!this.#token || nowSeconds >= this.#exp - 60) return null;
    return this.#token;
  }

  set(token: string, expSeconds: number): void {
    this.#token = token;
    this.#exp = expSeconds;
  }
}

export function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}
