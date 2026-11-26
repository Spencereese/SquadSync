import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildGameOnApnsPayload,
  buildGameOnFcmMessage,
  gameOnApnsHeaders,
  gameOnBanner,
  isGameOnInsert,
  isGameOnWebhook,
  readGameOnRecord,
} from "./gameon.ts";

const squad = "00000000-0000-0000-0000-000000000010";
const call = "00000000-0000-0000-0000-00000000c001";
const caller = "00000000-0000-0000-0000-000000000002";

const body = (record: Record<string, unknown>, extra: Record<string, unknown> = {}) => ({
  type: "INSERT",
  table: "sq8_spot_calls",
  schema: "public",
  record,
  ...extra,
});

const row = { id: call, squad_id: squad, caller_id: caller, kind: "game_on", game: "Warzone", seat_target: 2 };

Deno.test("only a sq8_spot_calls body is a Game on webhook", () => {
  assertEquals(isGameOnWebhook(body(row)), true);
  assertEquals(isGameOnWebhook({ table: "sq8_messages", record: row }), false);
  assertEquals(isGameOnWebhook({ table: "sq8_spot_calls", schema: "other", record: row }), false);
  assertEquals(isGameOnWebhook(null), false);
});

Deno.test("a row missing its caller is unreadable", () => {
  assertEquals(readGameOnRecord(body({ id: call, squad_id: squad, kind: "game_on" })), null);
  assertEquals(readGameOnRecord(body(row))?.seat_target, 2);
});

Deno.test("an old spot call or an update is not a new Game on", () => {
  const spot = readGameOnRecord(body({ ...row, kind: "spot" }))!;
  assertEquals(isGameOnInsert(body(spot), spot), false);
  const noKind = readGameOnRecord(body({ id: call, squad_id: squad, caller_id: caller, game: "Halo" }))!;
  assertEquals(noKind.kind, "spot", "a row from before 0028 has no kind, and is a spot call");
  const update = readGameOnRecord(body(row, { type: "UPDATE" }))!;
  assertEquals(isGameOnInsert(body(row, { type: "UPDATE" }), update), false);
  assertEquals(isGameOnInsert(body(row), readGameOnRecord(body(row))!), true);
});

Deno.test("the banner says who, what and how many", () => {
  const record = readGameOnRecord(body(row))!;
  assertEquals(gameOnBanner({ caller_name: "Riley", game: "Warzone", need: 1 }, record), {
    title: "Game on",
    body: "Riley's on Warzone, need 1",
  });
  assertEquals(gameOnBanner({ caller_name: "Riley", need: 0 }, record).body, "Riley's on Warzone, full");
  assertEquals(gameOnBanner(null, record).body, "Someone's on Warzone, need 1", "falls back to the row");
  const bare = readGameOnRecord(body({ id: call, squad_id: squad, caller_id: caller, kind: "game_on" }))!;
  assertEquals(gameOnBanner(null, bare).body, "Someone's on a game");
});

Deno.test("payloads carry type, squad and call, and collapse by call", () => {
  const record = readGameOnRecord(body(row))!;
  const banner = { title: "Game on", body: "Riley's on Warzone, need 1" };
  assertEquals(buildGameOnApnsPayload(record, banner), {
    aps: { alert: banner, "thread-id": `squad:${squad}`, sound: "default" },
    type: "game_on",
    squad_id: squad,
    call_id: call,
  });
  assertEquals(gameOnApnsHeaders(record), { "apns-collapse-id": `game_on:${call}` });
  const fcm = buildGameOnFcmMessage({ token: "t", record, banner }).message;
  assertEquals(fcm.data, { type: "game_on", squad_id: squad, call_id: call });
  assertEquals((fcm.android as { collapse_key: string }).collapse_key, `game_on:${call}`);
});
