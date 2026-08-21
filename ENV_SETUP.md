# Environment Setup

HLedger needs two things configured before it will run: **Firebase** (auth +
data) and, optionally, the **Cloudflare Worker** that powers AI chat.

Neither involves putting an API key in the app. That is deliberate — anything
compiled into an APK can be extracted from it.

---

## What goes where

| Secret | Lives in | In the APK? |
| --- | --- | --- |
| Firebase config | `android/app/google-services.json` | Yes — public by design, restricted by package name + SHA-1 |
| Groq API key | Cloudflare Worker Secret | **No** |
| Gemini API key | Cloudflare Worker Secret | **No** |
| Upload keystore | `android/app/upload-keystore.jks` + `android/key.properties` | No |

All four are gitignored. None of them belong in a commit, an issue, or a PR.

The only build-time value the app takes is `AI_PROXY_URL` — your Worker's public
address, which is not a secret.

---

## 1. Copy the templates

```bash
cp lib/core/constants/app_constants.dart.example lib/core/constants/app_constants.dart
cp dart_defines.example.json dart_defines.json
```

`dart_defines.json` holds exactly one entry:

```json
{
  "AI_PROXY_URL": "https://hledger-ai-worker.your-subdomain.workers.dev"
}
```

Leave it as `""` if you are not using AI chat — the app runs fine, and chat shows
a clear "not configured" message instead of failing oddly.

## 2. Firebase

Follow [FIREBASE_SETUP.md](FIREBASE_SETUP.md). The short version:

1. Create a project, enable **Email/Password** and **Google** sign-in.
2. Create a **Cloud Firestore** database (production mode). The region is
   permanent — pick the one nearest your users.
3. Add an Android app with package `com.hariverse.hledger`, download
   `google-services.json` into `android/app/`.
4. **Add your SHA-1 fingerprints** — debug *and* release — then **re-download**
   `google-services.json`. The fingerprints are baked into that file.
5. Deploy the rules: `firebase deploy --only firestore:rules`.

Two failure modes worth recognising:

- **Google Sign-In does nothing / `ApiException: 10`** — SHA-1 not registered, or
  the JSON wasn't re-downloaded after adding it. Email/password will still work,
  which makes this look like a UI bug rather than a config one.
- **Everything saves but nothing appears in the console** — the Firestore
  database was never created, or the rules reject the write. The app surfaces a
  red error for a rejected write, so silence here means the write landed.

## 3. Cloudflare Worker (optional — AI chat only)

```bash
cd backend/hledger-ai-worker
npx wrangler login
npx wrangler kv namespace create RATE_LIMIT   # paste the id into wrangler.toml
npx wrangler secret put GROQ_API_KEY
npx wrangler secret put GEMINI_API_KEY        # optional fallback provider
npx wrangler deploy
```

Confirm with `curl https://<your-worker>/health` — it reports whether each key is
*present*, never its value.

The Worker owns model selection, so there are no model names in the app to go
stale. Groq retires model slugs on a published schedule; the Worker queries the
live catalogue when the ones it knows stop resolving, and falls back to Gemini for
rate limits, outages and timeouts.

Details, including how the Firebase ID token authenticates the app to the Worker:
[backend/hledger-ai-worker/README.md](backend/hledger-ai-worker/README.md).

## 4. Run

```bash
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

## 5. Release build

```bash
flutter build appbundle --release \
  --dart-define=AI_PROXY_URL=https://your-worker.workers.dev
```

Signing reads `android/key.properties`:

```properties
storeFile=upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

Back the keystore up somewhere safe. Losing it means you cannot ship updates to an
already-published app.

---

## Troubleshooting

**"AI chat is configured nahi hai is build mein"** — `AI_PROXY_URL` was empty at
build time. Pass `--dart-define-from-file=dart_defines.json`.

**Chat returns a service error** — check `/health`. If a provider reads `false`,
its secret was never set: `npx wrangler secret put GROQ_API_KEY`.

**Chat says your session expired** — the Worker verifies a Firebase ID token, so
you must be signed in. Sign out and back in.

**Build fails with a missing `google-services.json`** — the google-services Gradle
plugin hard-fails without it. See step 2.

**Detection finds nothing** — both sources are opt-in from the Review Inbox, and
notification access has to be granted in Android Settings. Cash is never
detectable, and some apps word alerts in ways the parser cannot read.
