// Game on (public.sq8_spot_calls rows with kind = 'game_on', file 0028).
// Pure helpers, no network. Only a sq8_spot_calls webhook body takes this
// path; a spot call that isn't a Game on (an old build's spot call) is
// acknowledged and sends nothing, so old behaviour stays exactly as it was.

export type GameOnRecord = {
  id: string;
  squad_id: string;
  caller_id: string;
  kind: string;
  game: string;
  seat_target: number | null;
};

export type GameOnContext = {
  caller_name?: string | null;
  game?: string | null;
  need?: number | null;
  kind?: string | null;
};

export type GameOnBanner = {
  title: string;
  body: string;
};

export const gameOnTable = "sq8_spot_calls";

/// True only for a Database Webhook body from public.sq8_spot_calls.
export function isGameOnWebhook(body: unknown): boolean {
  if (!body || typeof body !== "object") return false;
  const table = (body as { table?: unknown }).table;
  const schema = (body as { schema?: unknown }).schema;
  return table === gameOnTable && (schema === undefined || schema === "public");
}

/// The row, or null when a field the push needs is missing. `kind` is read as
/// stored; the caller decides what a non-Game-on row means.
export function readGameOnRecord(body: unknown): GameOnRecord | null {
  if (!isGameOnWebhook(body)) return null;
  const record = (body as { record?: unknown }).record;
  if (!record || typeof record !== "object") return null;
  const row = record as Record<string, unknown>;
  for (const key of ["id", "squad_id", "caller_id"] as const) {
    if (typeof row[key] !== "string" || !(row[key] as string)) return null;
  }
  return {
    id: row.id as string,
    squad_id: row.squad_id as string,
    caller_id: row.caller_id as string,
    kind: typeof row.kind === "string" ? row.kind : "spot",
    game: typeof row.game === "string" ? row.game : "",
    seat_target: typeof row.seat_target === "number" ? row.seat_target : null,
  };
}

/// Only an INSERT of a Game on row notifies anyone.
export function isGameOnInsert(body: unknown, record: GameOnRecord): boolean {
  const type = (body as { type?: unknown }).type;
  return record.kind === "game_on" && (type === undefined || type === "INSERT");
}

export function gameOnKey(callId: string): string {
  return `game_on:${callId}`;
}

/// "Riley's on Warzone, need 1". The context (read with the service role) wins
/// over the webhook row; nothing is invented when both are missing.
export function gameOnBanner(context: GameOnContext | null, record: GameOnRecord): GameOnBanner {
  const name = context?.caller_name?.trim() || "Someone";
  const game = (context?.game ?? record.game).trim() || "a game";
  const fromRow = record.seat_target !== null ? Math.max(record.seat_target - 1, 0) : null;
  const need = typeof context?.need === "number" ? context.need : fromRow;
  const tail = need === null ? "" : need > 0 ? `, need ${need}` : ", full";
  return { title: "Game on", body: `${name}'s on ${game}${tail}` };
}

function tapData(record: GameOnRecord): Record<string, string> {
  return { type: "game_on", squad_id: record.squad_id, call_id: record.id };
}

/// Direct APNs body. Grouped with the group's chat; tap fields beside `aps`.
export function buildGameOnApnsPayload(record: GameOnRecord, banner: GameOnBanner): Record<string, unknown> {
  return {
    aps: {
      alert: { title: banner.title, body: banner.body },
      "thread-id": `squad:${record.squad_id}`,
      sound: "default",
    },
    ...tapData(record),
  };
}

export function gameOnApnsHeaders(record: GameOnRecord): Record<string, string> {
  return { "apns-collapse-id": gameOnKey(record.id) };
}

export function buildGameOnFcmMessage(input: {
  token: string;
  record: GameOnRecord;
  banner: GameOnBanner;
}): { message: Record<string, unknown> } {
  const key = gameOnKey(input.record.id);
  return {
    message: {
      token: input.token,
      data: tapData(input.record),
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
        payload: buildGameOnApnsPayload(input.record, input.banner),
      },
    },
  };
}
