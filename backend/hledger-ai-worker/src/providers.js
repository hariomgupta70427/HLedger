/**
 * Provider calls. Both keys live only in Worker Secrets and never leave here.
 *
 * Order is configurable because "best" changes: Groq is the verified-working
 * provider today, Gemini is the one whose model aliases cannot be retired out
 * from under us. Whichever runs first, the other is the safety net.
 */

const GROQ_CHAT = 'https://api.groq.com/openai/v1/chat/completions';
const GROQ_MODELS = 'https://api.groq.com/openai/v1/models';
const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';

/** Preferred Groq models. Verified against the live API 2026-08-20. */
const GROQ_PREFERRED = ['openai/gpt-oss-120b', 'groq/compound-mini'];

/** Gemini `-latest` aliases cannot be retired the way a pinned slug can. */
const GEMINI_PREFERRED = ['gemini-flash-latest', 'gemini-2.0-flash'];

const TIMEOUT_MS = 25000;

/** Failure kinds the client is allowed to know about. */
export const Failure = {
  modelMissing: 'model_unavailable',
  rateLimited: 'rate_limited',
  unauthorized: 'provider_auth_failed',
  timeout: 'timeout',
  server: 'provider_unavailable',
  malformed: 'malformed_response',
};

function supportsReasoningEffort(model) {
  return model.startsWith('openai/gpt-oss');
}

async function postJson(url, headers, body) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    return await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...headers },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Pulls a JSON object out of a model reply.
 *
 * Both providers are asked for JSON mode, so this normally parses first try. The
 * unwrapping is for the case where a model decides to be helpful and adds a code
 * fence anyway.
 */
function parseModelJson(text) {
  let body = String(text || '').trim();
  if (!body) return null;

  if (body.startsWith('```json')) body = body.slice(7);
  else if (body.startsWith('```')) body = body.slice(3);
  if (body.endsWith('```')) body = body.slice(0, -3);
  body = body.trim();

  if (!body.startsWith('{')) {
    const start = body.indexOf('{');
    const end = body.lastIndexOf('}');
    if (start === -1 || end <= start) return null;
    body = body.slice(start, end + 1);
  }

  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== 'object') return null;

  const allowed = ['ADD_TRANSACTION', 'ADD_TASK', 'GET_BALANCE', 'NONE'];
  const action = allowed.includes(parsed.action) ? parsed.action : 'NONE';
  const reply = typeof parsed.reply === 'string' ? parsed.reply : '';
  if (!reply) return null;

  return {
    action,
    reply,
    data: parsed.data && typeof parsed.data === 'object' ? parsed.data : null,
  };
}

function classify(status, bodyText) {
  if (status === 404) return Failure.modelMissing;
  if (status === 429) return Failure.rateLimited;
  if (status === 401 || status === 403) return Failure.unauthorized;
  if (status === 400) {
    // Gemini reports a bad key as 400 API_KEY_INVALID rather than 401.
    if (String(bodyText).includes('API_KEY_INVALID')) return Failure.unauthorized;
    return Failure.malformed;
  }
  if (status >= 500) return Failure.server;
  return Failure.malformed;
}

// ── Groq ──

async function groqModels(apiKey) {
  try {
    const response = await fetch(GROQ_MODELS, {
      headers: { Authorization: `Bearer ${apiKey}` },
    });
    if (!response.ok) return [];
    const body = await response.json();
    const excluded = ['whisper', 'orpheus', 'tts', 'guard', 'embed', 'allam', 'safeguard'];
    const rank = (id) => {
      const lower = id.toLowerCase();
      if (lower.includes('120b')) return 0;
      if (lower.includes('70b')) return 1;
      if (lower.includes('compound-mini')) return 2;
      if (lower.includes('compound')) return 3;
      return 4;
    };
    return (body.data || [])
      .map((entry) => String(entry.id || ''))
      .filter((id) => id && !excluded.some((bad) => id.toLowerCase().includes(bad)))
      .sort((a, b) => rank(a) - rank(b));
  } catch {
    return [];
  }
}

async function callGroq(apiKey, messages, models) {
  let worst = null;

  for (const model of models) {
    const body = {
      model,
      messages,
      temperature: 0.7,
      // Every model on the free tier is a reasoning model and its reasoning
      // tokens share this budget, so a small cap truncates the JSON mid-object.
      max_tokens: 1024,
      response_format: { type: 'json_object' },
    };
    if (supportsReasoningEffort(model)) body.reasoning_effort = 'low';

    let response;
    try {
      response = await postJson(GROQ_CHAT, { Authorization: `Bearer ${apiKey}` }, body);
    } catch (error) {
      worst = worst || (error.name === 'AbortError' ? Failure.timeout : Failure.server);
      continue;
    }

    if (!response.ok) {
      const text = await response.text();
      const failure = classify(response.status, text);
      worst = worst || failure;
      console.log(`groq ${model} -> ${response.status} (${failure})`);
      if (failure === Failure.unauthorized) break;
      continue;
    }

    const payload = await response.json();
    const parsed = parseModelJson(payload?.choices?.[0]?.message?.content);
    if (parsed) return { ok: true, provider: 'groq', model, ...parsed };
    worst = worst || Failure.malformed;
  }

  return { ok: false, failure: worst || Failure.malformed };
}

// ── Gemini ──

async function callGemini(apiKey, messages) {
  const system = messages
    .filter((m) => m.role === 'system')
    .map((m) => m.content)
    .join('\n');
  const contents = messages
    .filter((m) => m.role !== 'system')
    .map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: String(m.content ?? '') }],
    }));

  let worst = null;

  for (const model of GEMINI_PREFERRED) {
    const body = {
      contents,
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 1024,
        responseMimeType: 'application/json',
      },
    };
    if (system) body.systemInstruction = { parts: [{ text: system }] };

    let response;
    try {
      response = await postJson(
        `${GEMINI_BASE}/${model}:generateContent`,
        // Header rather than ?key=, so the secret cannot land in a logged URL.
        { 'x-goog-api-key': apiKey },
        body,
      );
    } catch (error) {
      worst = worst || (error.name === 'AbortError' ? Failure.timeout : Failure.server);
      continue;
    }

    if (!response.ok) {
      const text = await response.text();
      const failure = classify(response.status, text);
      worst = worst || failure;
      console.log(`gemini ${model} -> ${response.status} (${failure})`);
      if (failure === Failure.unauthorized) break;
      continue;
    }

    const payload = await response.json();
    const text = (payload?.candidates?.[0]?.content?.parts || [])
      .map((part) => part?.text || '')
      .join('');
    const parsed = parseModelJson(text);
    if (parsed) return { ok: true, provider: 'gemini', model, ...parsed };
    worst = worst || Failure.malformed;
  }

  return { ok: false, failure: worst || Failure.malformed };
}

/**
 * Tries each configured provider in order and returns the first usable reply.
 *
 * A provider whose key is missing is skipped rather than failed, so the Worker
 * runs correctly with only one secret configured.
 */
export async function complete(env, messages) {
  const order = String(env.PROVIDER_ORDER || 'groq,gemini')
    .split(',')
    .map((name) => name.trim().toLowerCase())
    .filter(Boolean);

  let worst = null;

  for (const provider of order) {
    if (provider === 'groq') {
      if (!env.GROQ_API_KEY) continue;
      let models = GROQ_PREFERRED;
      let result = await callGroq(env.GROQ_API_KEY, messages, models);
      // Every slug we knew about is gone: ask what the account actually serves
      // now, so a retirement does not take chat down until the next deploy.
      if (!result.ok && result.failure === Failure.modelMissing) {
        const live = await groqModels(env.GROQ_API_KEY);
        if (live.length) {
          console.log(`groq rediscovered: ${live.slice(0, 3).join(', ')}`);
          result = await callGroq(env.GROQ_API_KEY, messages, live);
        }
      }
      if (result.ok) return result;
      worst = worst || result.failure;
    }

    if (provider === 'gemini') {
      if (!env.GEMINI_API_KEY) continue;
      const result = await callGemini(env.GEMINI_API_KEY, messages);
      if (result.ok) return result;
      worst = worst || result.failure;
    }
  }

  return { ok: false, failure: worst || Failure.server };
}
