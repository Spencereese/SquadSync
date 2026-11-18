// The webhook secret check. index.ts runs it before anything else, so a caller
// without the header learns nothing (not even which secrets are unset): it gets
// a 401. An unset SQ8_PUSH_WEBHOOK_SECRET also refuses everyone.

export function webhookAuthorized(
  expected: string | undefined | null,
  provided: string | undefined | null,
): boolean {
  if (!expected || !provided) return false;
  const a = new TextEncoder().encode(expected);
  const b = new TextEncoder().encode(provided);
  // Compare every byte so the time taken doesn't hint at how much matched.
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}

export function unauthorizedResponse(headers: Record<string, string>): Response {
  return new Response(JSON.stringify({ ok: false, reason: "unauthorized" }), {
    status: 401,
    headers,
  });
}
