import {
  AccessTokenCache,
  buildMessagingClaims,
  buildSquadMessage,
  encodeJson,
  jwtSigningInput,
  tokenShouldBeDropped,
} from "./fcm.ts";

function assertEqual(actual: unknown, expected: unknown): void {
  const left = JSON.stringify(actual);
  const right = JSON.stringify(expected);
  if (left !== right) throw new Error(`${left} != ${right}`);
}

const account = {
  client_email: "push@squadsync.iam.gserviceaccount.com",
  private_key: "unused",
  project_id: "squadsync-dev",
};

Deno.test("messaging claims ask only for FCM and expire in an hour", () => {
  const claims = buildMessagingClaims(account, 1_700_000_000);
  assertEqual(claims, {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: 1_700_000_000,
    exp: 1_700_003_600,
  });
  const [, payload] = jwtSigningInput(account, 1_700_000_000).split(".");
  const padded = payload.replaceAll("-", "+").replaceAll("_", "/");
  const json = JSON.parse(atob(padded));
  assertEqual(json.iss, account.client_email);
  assertEqual(json.scope, "https://www.googleapis.com/auth/firebase.messaging");
  assertEqual(json.exp, 1_700_003_600);
  assertEqual(encodeJson({ alg: "RS256", typ: "JWT" }).includes(" "), false);
});

Deno.test("the payload threads by squad and repeats the tap data for iOS", () => {
  const body = buildSquadMessage({
    token: "device-token",
    squadId: "squad-1",
    messageId: "msg-1",
  });
  const message = body.message;
  const data = message.data as Record<string, string>;
  const apns = message.apns as {
    headers: Record<string, string>;
    payload: Record<string, unknown>;
  };
  const android = message.android as { collapse_key: string };
  assertEqual(data, {
    type: "squad_message",
    squad_id: "squad-1",
    message_id: "msg-1",
  });
  assertEqual(android.collapse_key, "squad:squad-1");
  assertEqual(apns.headers["apns-collapse-id"], "squad:squad-1");
  assertEqual(
    (apns.payload.aps as { "thread-id": string })["thread-id"],
    "squad:squad-1",
  );
  assertEqual(apns.payload.squad_id, "squad-1");
  assertEqual(apns.payload.message_id, "msg-1");
  assertEqual(apns.payload.type, "squad_message");
});

Deno.test("only an unregistered or invalid token is dropped", () => {
  assertEqual(
    tokenShouldBeDropped({
      error: {
        status: "NOT_FOUND",
        details: [{ errorCode: "UNREGISTERED" }],
      },
    }),
    true,
  );
  assertEqual(
    tokenShouldBeDropped({
      error: { status: "INVALID_ARGUMENT", details: [] },
    }),
    true,
  );
  assertEqual(
    tokenShouldBeDropped({
      error: { status: "UNAVAILABLE", details: [{ errorCode: "INTERNAL" }] },
    }),
    false,
  );
  assertEqual(tokenShouldBeDropped(null), false);
});

Deno.test("the access token is reused until a minute before it expires", () => {
  const cache = new AccessTokenCache();
  assertEqual(cache.get(100), null);
  cache.set("minted", 4600);
  assertEqual(cache.get(1000), "minted");
  assertEqual(cache.get(4540), null);
});
