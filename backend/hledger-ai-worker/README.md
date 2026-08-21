# HLedger AI Worker

Server-side proxy for AI chat. **The app ships with no provider keys.**

**Deployed:** <https://hledger-ai-worker.guptahariom049.workers.dev>
KV namespace `RATE_LIMIT` = `f75f51f9e0b34cd3b037356886fec810`

## Remaining step — set the two secrets (you must do this)

Both keys were exposed in earlier debug APKs, so **rotate first, then set the new
ones**. Nothing else is outstanding; the Worker, its KV binding and its auth are
already live.

```bash
cd backend/hledger-ai-worker

# Paste the NEW key when prompted — it is never written to a file or to shell history.
npx wrangler secret put GROQ_API_KEY
npx wrangler secret put GEMINI_API_KEY

# Confirm both now read true:
curl https://hledger-ai-worker.guptahariom049.workers.dev/health
```

`/health` reports only whether each key is *present*, never its value.

## Why this exists

`--dart-define` values are compiled into the APK and are extractable by anyone
who decompiles it. A leaked Groq or Gemini key means someone else spends your
free-tier quota, and there is no way to rotate it out of an app that is already
installed. Both keys now live only in Cloudflare Worker Secrets.

## Rebuilding the app against it

```bash
flutter build appbundle --release \
  --dart-define=AI_PROXY_URL=https://hledger-ai-worker.guptahariom049.workers.dev
```

`AI_PROXY_URL` is a public endpoint address, not a secret — it is safe in the APK.

## Rotate the previously exposed keys

1. Groq console → delete the old key → create a new one → `wrangler secret put GROQ_API_KEY`.
2. Google AI Studio → same → `wrangler secret put GEMINI_API_KEY`.

Note: the old `dart_defines.json` spelled the second key `Gemini_KEY`, so
`GEMINI_KEY` never resolved and the Gemini fallback had never actually run.


## Auth

`POST /chat` requires `Authorization: Bearer <Firebase ID token>`. The token is
verified against Google's JWKS — signature, expiry, audience and issuer — so only
a real signed-in HLedger user can spend quota, and each uid is rate-limited
separately.

A shared API secret was rejected for this: it would have to ship in the APK, which
is the exact problem this Worker removes.

## Rate limits

Defaults are 12 requests/minute and 300/day per user, set in `[vars]`. KV is
eventually consistent, so these are bounds rather than hard gates — enough that
the endpoint cannot become an unlimited public AI proxy.

## Logging

Logs record the uid, the provider, the model and a failure code. They never
record message content, and never any part of a key.
