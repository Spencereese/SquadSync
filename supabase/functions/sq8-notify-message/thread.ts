// Side-thread replies (public.sq8_thread_messages). Pure helpers, no network.
// The webhook body names its table; only a sq8_thread_messages body takes this
// path. Everything else keeps the squad-message path exactly as it was.

export type ThreadMessageRecord = {
  id: string;
  thread_id: string;
  squad_id: string;
  sender_id: string;
  body: string;
};

export type ThreadContext = {
  thread_kind?: string | null;
  thread_title?: string | null;
  sender_name?: string | null;
};

export type ThreadBanner = {
  title: string;
  body: string;
};

export const threadTable = "sq8_thread_messages";
export const previewLimit = 140;

/// True only for a Database Webhook body from public.sq8_thread_messages.
export function isThreadWebhook(body: unknown): boolean {
  if (!body || typeof body !== "object") return false;
  const table = (body as { table?: unknown }).table;
  const schema = (body as { schema?: unknown }).schema;
  return table === threadTable && (schema === undefined || schema === "public");
}

export function readThreadRecord(body: unknown): ThreadMessageRecord | null {
  if (!isThreadWebhook(body)) return null;
  const record = (body as { record?: unknown }).record;
  if (!record || typeof record !== "object") return null;
  const row = record as Partial<Record<keyof ThreadMessageRecord, unknown>>;
  for (const key of ["id", "thread_id", "squad_id", "sender_id"] as const) {
    if (typeof row[key] !== "string" || !(row[key] as string)) return null;
  }
  return {
    id: row.id as string,
    thread_id: row.thread_id as string,
    squad_id: row.squad_id as string,
    sender_id: row.sender_id as string,
    body: typeof row.body === "string" ? row.body : "",
  };
}

export function threadKey(threadId: string): string {
  return `thread:${threadId}`;
}

/// Whitespace folded to single spaces, cut at `limit` characters (not UTF-16
/// units, so an emoji is never split) with an ellipsis.
export function previewText(body: string, limit = previewLimit): string {
  const folded = body.replace(/\s+/g, " ").trim();
  const chars = Array.from(folded);
  if (chars.length <= limit) return folded;
  return `${chars.slice(0, limit - 1).join("").trimEnd()}…`;
}

/// "Riley in Ranked" for a side group, "Riley · Direct message" for a DM.
/// The body is the reply itself. Nothing is invented when a field is missing.
export function threadBanner(context: ThreadContext | null, body: string): ThreadBanner {
  const sender = context?.sender_name?.trim() || "Someone";
  const kind = context?.thread_kind ?? "side_group";
  const title = context?.thread_title?.trim();
  const heading = kind === "dm"
    ? `${sender} · Direct message`
    : `${sender} in ${title || "a side thread"}`;
  const preview = previewText(body);
  return { title: heading, body: preview || "Sent a reply" };
}

function tapData(record: ThreadMessageRecord): Record<string, string> {
  return {
    type: "thread_message",
    squad_id: record.squad_id,
    thread_id: record.thread_id,
    message_id: record.id,
  };
}

/// The direct APNs body. Tap fields sit beside `aps` so a cold launch has them.
export function buildThreadApnsPayload(
  record: ThreadMessageRecord,
  banner: ThreadBanner,
): Record<string, unknown> {
  return {
    aps: {
      alert: { title: banner.title, body: banner.body },
      "thread-id": threadKey(record.thread_id),
      sound: "default",
    },
    ...tapData(record),
  };
}

/// Direct APNs request headers beyond auth and topic: collapse by thread.
export function threadApnsHeaders(record: ThreadMessageRecord): Record<string, string> {
  return { "apns-collapse-id": threadKey(record.thread_id) };
}

/// FCM HTTP v1 body. Collapses and threads by side thread, not by squad.
export function buildThreadFcmMessage(input: {
  token: string;
  record: ThreadMessageRecord;
  banner: ThreadBanner;
}): { message: Record<string, unknown> } {
  const key = threadKey(input.record.thread_id);
  const data = tapData(input.record);
  return {
    message: {
      token: input.token,
      data,
      notification: { title: input.banner.title, body: input.banner.body },
      android: {
        collapse_key: key,
        priority: "HIGH",
        notification: { tag: key },
      },
      apns: {
        headers: {
          "apns-collapse-id": key,
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: buildThreadApnsPayload(input.record, input.banner),
      },
    },
  };
}
