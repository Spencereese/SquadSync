import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildApnsPayload, missingApnsSecrets } from "./apns.ts";

Deno.test("a message tap carries the squad and the message", () => {
  const payload = buildApnsPayload({
    squadId: "00000000-0000-0000-0000-000000000010",
    messageId: "00000000-0000-0000-0000-00000000a001",
  });
  assertEquals(payload.type, "squad_message");
  assertEquals(payload.squad_id, "00000000-0000-0000-0000-000000000010");
  assertEquals(payload.message_id, "00000000-0000-0000-0000-00000000a001");
});

Deno.test("a squad tap has no message id", () => {
  const payload = buildApnsPayload({
    squadId: "00000000-0000-0000-0000-000000000010",
    kind: "squad",
  });
  assertEquals(payload.type, "squad");
  assertEquals(payload.message_id, undefined);
});

Deno.test("the APNs key names are the human gate", () => {
  assertEquals(missingApnsSecrets({}), [
    "APNS_KEY_P8",
    "APNS_KEY_ID",
    "APNS_TEAM_ID",
    "APNS_BUNDLE_ID",
  ]);
  assertEquals(
    missingApnsSecrets({
      APNS_KEY_P8: "present",
      APNS_KEY_ID: "present",
      APNS_TEAM_ID: "present",
      APNS_BUNDLE_ID: "present",
    }),
    [],
  );
});
