'use strict';

const CONCIERGE_COMMANDS = new Set([
  'whos_free_tonight',
  'summarize_lobby_chat',
  'draft_peacock_invite',
]);

function utcDay(now = new Date()) {
  return now.toISOString().slice(0, 10);
}

function isConciergeCommand(command) {
  return typeof command === 'string' && CONCIERGE_COMMANDS.has(command);
}

/**
 * Process-local daily cap for xAI spend.
 * Cloud Run instances do not share this map — set an xAI console spend
 * limit for a global hard stop.
 */
function createGrokBudget(env = process.env) {
  const usdCap = Number(env.XAI_DAILY_SPEND_CAP_USD ?? 1);
  const callCap = Number(env.XAI_DAILY_MAX_CALLS ?? 30);
  const inUsdPerM = Number(env.XAI_INPUT_USD_PER_M ?? 3);
  const outUsdPerM = Number(env.XAI_OUTPUT_USD_PER_M ?? 15);
  const state = { day: utcDay(), calls: 0, usd: 0 };

  function roll(now = new Date()) {
    const day = utcDay(now);
    if (state.day !== day) {
      state.day = day;
      state.calls = 0;
      state.usd = 0;
    }
  }

  function snapshot(now = new Date()) {
    roll(now);
    return {
      day: state.day,
      calls: state.calls,
      usd: Number(state.usd.toFixed(6)),
      usdCap,
      callCap,
    };
  }

  function check(now = new Date()) {
    roll(now);
    if (state.calls >= callCap) {
      return { ok: false, reason: 'call_cap', ...snapshot(now) };
    }
    if (state.usd >= usdCap) {
      return { ok: false, reason: 'usd_cap', ...snapshot(now) };
    }
    return { ok: true, ...snapshot(now) };
  }

  function record(usage, now = new Date()) {
    roll(now);
    const inTok = Number(usage && usage.prompt_tokens != null ? usage.prompt_tokens : 800);
    const outTok = Number(
      usage && usage.completion_tokens != null ? usage.completion_tokens : 150,
    );
    const usd = (inTok / 1e6) * inUsdPerM + (outTok / 1e6) * outUsdPerM;
    state.calls += 1;
    state.usd += usd;
    return snapshot(now);
  }

  return { check, record, snapshot, usdCap, callCap };
}

module.exports = {
  createGrokBudget,
  isConciergeCommand,
  CONCIERGE_COMMANDS,
  utcDay,
};
