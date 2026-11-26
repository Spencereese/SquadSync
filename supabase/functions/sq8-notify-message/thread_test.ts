import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildThreadApnsPayload,
  buildThreadFcmMessage,
  isThreadWebhook,
  previewText,
  readThreadRecord,
  threadApnsHeaders,
  threadBanner,
} from "./thread.ts";

const record = {
  id: "00000000-0000-0000-0000-00000000b103",
  thread_id: "00000000-0000-0000-0000-00000000b001",
  squad_id: "00000000-0000-0000-0000-000000000010",
  sender_id: "00000000-0000-0000-0000-000000000002",
  body: "on in 5",
};

Deno.test("only a public.sq8_thread_messages body is a thread webhook", () => {
  assertEquals(isThreadWebhook({ table: "sq8_thread_messages", schema: "public", record }), true);
  assertEquals(isThreadWebhook({ table: "sq8_thread_messages", record }), true);
  assertEquals(isThreadWebhook({ table: "sq8_messages", schema: "public", record }), false);
  assertEquals(isThreadWebhook({ table: "sq8_thread_messages", schema: "private", record }), false);
  assertEquals(isThreadWebhook({ record }), false);
  assertEquals(isThreadWebhook(null), false);
  assertEquals(isThreadWebhook("sq8_thread_messages"), false);
});

Deno.test("a thread record needs its id, thread, squad, and sender", () => {
  const body = { table: "sq8_thread_messages", schema: "public", record };
  assertEquals(readThreadRecord(body), record);
  for (const key of ["id", "thread_id", "squad_id", "sender_id"]) {
    const partial: Record<string, unknown> = { ...record };
    delete partial[key];
    assertEquals(readThreadRecord({ ...body, record: partial }), null, key);
    assertEquals(readThreadRecord({ ...body, record: { ...record, [key]: "" } }), null, `${key} blank`);
  }
  assertEquals(readThreadRecord({ ...body, record: { ...record, body: undefined } })?.body, "");
  assertEquals(readThreadRecord({ table: "sq8_messages", record }), null);
});

Deno.test("the preview folds whitespace and cuts long replies on a character", () => {
  assertEquals(previewText("  a\n\nb\tc  "), "a b c");
  const long = "x".repeat(200);
  const cut = previewText(long);
  assertEquals(Array.from(cut).length, 140);
  assertEquals(cut.endsWith("…"), true);
  assertEquals(previewText("🎮".repeat(10), 5), "🎮🎮🎮🎮…");
  assertEquals(previewText("short", 5), "short");
});

Deno.test("the banner names the sender and the thread", () => {
  assertEquals(
    threadBanner({ thread_kind: "side_group", thread_title: "Ranked", sender_name: "Riley" }, "on in 5"),
    { title: "Riley in Ranked", body: "on in 5" },
  );
  assertEquals(
    threadBanner({ thread_kind: "dm", thread_title: null, sender_name: "Riley" }, "u on?"),
    { title: "Riley · Direct message", body: "u on?" },
  );
  assertEquals(threadBanner(null, "hi"), { title: "Someone in a side thread", body: "hi" });
  assertEquals(
    threadBanner({ thread_kind: "side_group", thread_title: "  ", sender_name: " " }, "   "),
    { title: "Someone in a side thread", body: "Sent a reply" },
  );
});

Deno.test("APNs: tap data beside aps, threaded and collapsed by thread", () => {
  const banner = { title: "Riley in Ranked", body: "on in 5" };
  const payload = buildThreadApnsPayload(record, banner);
  assertEquals(payload, {
    aps: {
      alert: banner,
      "thread-id": "thread:00000000-0000-0000-0000-00000000b001",
      sound: "default",
    },
    type: "thread_message",
    squad_id: record.squad_id,
    thread_id: record.thread_id,
    message_id: record.id,
  });
  assertEquals(threadApnsHeaders(record), { "apns-collapse-id": "thread:00000000-0000-0000-0000-00000000b001" });
});

Deno.test("FCM: data, notification, and collapse by thread", () => {
  const banner = { title: "Riley in Ranked", body: "on in 5" };
  const { message } = buildThreadFcmMessage({ token: "device", record, banner });
  assertEquals(message.token, "device");
  assertEquals(message.data, {
    type: "thread_message",
    squad_id: record.squad_id,
    thread_id: record.thread_id,
    message_id: record.id,
  });
  assertEquals(message.notification, banner);
  const android = message.android as { collapse_key: string; notification: { tag: string } };
  assertEquals(android.collapse_key, "thread:00000000-0000-0000-0000-00000000b001");
  assertEquals(android.notification.tag, "thread:00000000-0000-0000-0000-00000000b001");
  const apns = message.apns as { headers: Record<string, string>; payload: Record<string, unknown> };
  assertEquals(apns.headers["apns-collapse-id"], "thread:00000000-0000-0000-0000-00000000b001");
  assertEquals(apns.payload.type, "thread_message");
  assertEquals(apns.payload.thread_id, record.thread_id);
  assertEquals((apns.payload.aps as { "thread-id": string })["thread-id"], "thread:00000000-0000-0000-0000-00000000b001");
});
