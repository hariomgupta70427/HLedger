/**
 * HLedger AI proxy.
 *
 * Exists for one reason: a provider key compiled into an APK is extractable by
 * anyone who decompiles it, and a drained free-tier quota is the least of what
 * follows. Both keys now live in Worker Secrets, the app holds none, and the app
 * authenticates as a real signed-in user rather than with a shared token that
 * would have the same problem as the keys.
 *
 * POST /chat   Authorization: Bearer <firebase id token>
 *   { message: string, history?: [{role, content}], now?: ISO-8601 local }
 *   -> 200 { action, reply, data, provider, model }
 *   -> 4xx/5xx { error, message }
 *
 * GET /health -> 200 { ok, providers: { groq, gemini } }   (no secrets echoed)
 */

import { verifyFirebaseIdToken, AuthError } from './auth.js';
import { complete, Failure } from './providers.js';
import { SYSTEM_PROMPT } from './prompt.js';

const MAX_MESSAGE_CHARS = 1000;
const MAX_HISTORY_TURNS = 10;

/** Client-facing messages. Provider text is never forwarded verbatim. */
const MESSAGES = {
  [Failure.modelMissing]:
    'AI model badal gaya hai aur naya mila nahi. Thodi der baad try karo.',
  [Failure.rateLimited]: 'AI abhi busy hai. Ek minute baad dobara bolo.',
  [Failure.unauthorized]: 'AI service configured nahi hai. Support ko batao.',
  [Failure.timeout]: 'AI ne jawab dene mein bahut time laga. Dobara try karo.',
  [Failure.server]: 'AI service down hai abhi. Thodi der baad try karo.',
  [Failure.malformed]: 'AI ka jawab poora nahi aaya. Ek baar dobara bolo?',
};

const STATUS = {
  [Failure.modelMissing]: 503,
  [Failure.rateLimited]: 429,
  [Failure.unauthorized]: 500,
  [Failure.timeout]: 504,
  [Failure.server]: 502,
  [Failure.malformed]: 502,
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

function fail(code, message, status) {
  return json({ error: code, message }, status);
}

/**
 * Per-user request budget.
 *
 * KV is eventually consistent, so this is a bound rather than a hard gate — the
 * point is that a public endpoint cannot be turned into an unlimited AI proxy,
 * not that the 16th request in a minute is impossible. Two windows, because a
 * per-minute cap alone still allows a very expensive day.
 */
async function withinBudget(env, uid) {
  if (!env.RATE_LIMIT) {
    console.log('RATE_LIMIT KV not bound — abuse protection disabled');
    return true;
  }

  const perMinute = Number(env.RATE_MAX_PER_MINUTE || 12);
  const perDay = Number(env.RATE_MAX_PER_DAY || 300);
  const nowSeconds = Math.floor(Date.now() / 1000);

  const windows = [
    { key: `rl:m:${uid}:${Math.floor(nowSeconds / 60)}`, limit: perMinute, ttl: 120 },
    { key: `rl:d:${uid}:${Math.floor(nowSeconds / 86400)}`, limit: perDay, ttl: 172800 },
  ];

  for (const window of windows) {
    const used = Number((await env.RATE_LIMIT.get(window.key)) || 0);
    if (used >= window.limit) return false;
  }
  // Incremented only once the request is allowed through.
  await Promise.all(
    windows.map((window) =>
      env.RATE_LIMIT.get(window.key).then((value) =>
        env.RATE_LIMIT.put(window.key, String(Number(value || 0) + 1), {
          expirationTtl: window.ttl,
        }),
      ),
    ),
  );
  return true;
}

/** Trims and bounds whatever the client sent. */
function buildMessages(body) {
  const message = String(body?.message ?? '').trim().slice(0, MAX_MESSAGE_CHARS);
  if (!message) return null;

  const history = Array.isArray(body?.history) ? body.history : [];
  const turns = history
    .filter((turn) => turn && (turn.role === 'user' || turn.role === 'assistant'))
    .slice(-MAX_HISTORY_TURNS)
    .map((turn) => ({
      role: turn.role,
      content: String(turn.content ?? '').slice(0, MAX_MESSAGE_CHARS),
    }))
    .filter((turn) => turn.content);

  // The device supplies its own local time: the Worker runs in UTC at an
  // arbitrary edge location, so resolving "kal" here would be wrong.
  const stamp = String(body?.now ?? '').slice(0, 32);
  const when = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(stamp)
    ? stamp
    : new Date().toISOString().slice(0, 16);
  const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const day = weekdays[new Date(`${when}:00Z`).getUTCDay()] || 'Monday';

  const dateContext =
    `TODAY is ${when.slice(0, 10)} (${day}). Current time is ${when.slice(11, 16)}. ` +
    'Resolve all relative dates/times against this.';

  return [
    { role: 'system', content: `${SYSTEM_PROMPT}\n${dateContext}` },
    ...turns,
    { role: 'user', content: message },
  ];
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      return json({
        ok: true,
        // Presence only. Never the values.
        providers: {
          groq: Boolean(env.GROQ_API_KEY),
          gemini: Boolean(env.GEMINI_API_KEY),
        },
        rateLimiting: Boolean(env.RATE_LIMIT),
      });
    }

    if (url.pathname !== '/chat') return fail('not_found', 'Unknown endpoint.', 404);
    if (request.method !== 'POST') return fail('method_not_allowed', 'Use POST.', 405);

    const header = request.headers.get('Authorization') || '';
    const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';

    let uid;
    try {
      uid = await verifyFirebaseIdToken(token, env.FIREBASE_PROJECT_ID);
    } catch (error) {
      if (error instanceof AuthError) {
        console.log(`auth rejected: ${error.reason}`);
        const status = error.reason === 'server_misconfigured' ? 500 : 401;
        return fail('unauthenticated', 'Sign in again to use AI chat.', status);
      }
      console.log(`auth error: ${error?.name}`);
      return fail('unauthenticated', 'Could not verify your session.', 401);
    }

    if (!(await withinBudget(env, uid))) {
      return fail('rate_limited', MESSAGES[Failure.rateLimited], 429);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return fail('bad_request', 'Body must be JSON.', 400);
    }

    const messages = buildMessages(body);
    if (!messages) return fail('bad_request', 'A non-empty message is required.', 400);

    const result = await complete(env, messages);
    if (!result.ok) {
      console.log(`chat failed for ${uid}: ${result.failure}`);
      return fail(
        result.failure,
        MESSAGES[result.failure] || MESSAGES[Failure.server],
        STATUS[result.failure] || 502,
      );
    }

    return json({
      action: result.action,
      reply: result.reply,
      data: result.data,
      provider: result.provider,
      model: result.model,
    });
  },
};
