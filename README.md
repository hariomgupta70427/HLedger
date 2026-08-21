# HLedger

A personal finance and task app for India that fills in your ledger for you.

HLedger reads the transaction alerts your bank and payment apps already send —
bank SMS and payment-app notifications — and turns them into ledger entries you
confirm with one tap. You can also just talk to it: *"aaj 450 ka petrol daala"*
becomes an expense, *"kal subah 8 baje gym"* becomes a reminder.

Built with Flutter, Firebase, and a Cloudflare Worker for AI.

---

## Features

- **Automatic transaction detection** from bank SMS and payment-app
  notifications (GPay, PhonePe, Paytm, Amazon Pay, BHIM, CRED, bank apps).
  Nothing is saved until you confirm it.
- **Review inbox** — every detection lands here first, with a confidence badge.
- **Conversational entry** — Hinglish/Hindi/English chat that creates
  transactions and reminders.
- **Dashboard** — balance with income and expense shown separately, this
  month's spend, a 7-day chart scaled to a fixed reference, category breakdown.
- **Insights** — spending analytics by period and category.
- **Tasks with reminders** — exact when Android permits it, approximate
  otherwise, and it tells you which.
- **Offline-first** — Firestore's local cache means entries save without a
  network and sync when one returns.
- **Home screen widgets** for spend, tasks and quick notes.
- **Account screen** — who you are signed in as, and one-tap permanent deletion
  of the account and everything under it.

## Architecture

| Layer | Choice |
| --- | --- |
| App | Flutter 3.35 / Dart 3.9, Provider for state |
| Auth | Firebase Auth (email/password + Google via Credential Manager) |
| Data | Cloud Firestore, per-user subcollections `users/{uid}/…` |
| Detection (notifications) | Native Kotlin `NotificationListenerService` |
| Detection (SMS) | `another_telephony` with a background isolate |
| AI | Cloudflare Worker proxying Groq → Gemini |
| Parsing | Pure-Dart regex parser, no ML, no network |

Two design decisions worth knowing up front:

**Notification capture is native, not Dart.** Android keeps the listener service
bound long after the Flutter engine is gone. A capture path living in Dart misses
every alert that arrives while the app is closed — which is most of them. The
Kotlin service writes each allowlisted alert straight to disk; Dart reads that
queue when it next runs and confirms what it stored.

**The app ships no AI keys.** Anything passed through `--dart-define` is
compiled into the APK and extractable. Both provider keys live in Cloudflare
Worker Secrets; the app authenticates to the Worker with the Firebase ID token it
already holds.

## Getting started

```bash
flutter pub get
cp lib/core/constants/app_constants.dart.example lib/core/constants/app_constants.dart
cp dart_defines.example.json dart_defines.json
```

### 1. Firebase

See [FIREBASE_SETUP.md](FIREBASE_SETUP.md). In short: create a project, enable
Email/Password + Google sign-in, create a Firestore database, then drop
`google-services.json` into `android/app/`.

Two things that fail silently if skipped:

- **Register your SHA-1 fingerprints** (debug *and* release) in Firebase, then
  re-download `google-services.json`. Without them Google Sign-In fails with
  `ApiException: 10` while email/password keeps working.
- **Deploy the security rules**: `firebase deploy --only firestore:rules`.
  `firestore.rules` restricts every document to the account that created it.

### 2. AI backend (optional)

Chat needs the Worker. Everything else works without it.

```bash
cd backend/hledger-ai-worker
npx wrangler kv namespace create RATE_LIMIT   # paste the id into wrangler.toml
npx wrangler secret put GROQ_API_KEY
npx wrangler secret put GEMINI_API_KEY        # optional fallback
npx wrangler deploy
```

Full notes in [backend/hledger-ai-worker/README.md](backend/hledger-ai-worker/README.md).

### 3. Run

```bash
flutter run --dart-define-from-file=dart_defines.json
```

`dart_defines.json` holds one value, `AI_PROXY_URL` — your Worker's public
address. It is not a secret. **Never put an API key there.**

## Building a release

```bash
flutter build appbundle --release \
  --dart-define=AI_PROXY_URL=https://your-worker.workers.dev
```

Release signing reads `android/key.properties`, which points at your upload
keystore. Neither is in this repo, and neither should be.

## Permissions

Both detection sources are optional, each behind a separate in-app disclosure
shown before Android's own prompt. The app is fully usable with neither.

| Permission | Why |
| --- | --- |
| `READ_SMS`, `RECEIVE_SMS` | Read transactional bank SMS. Never sent. Requires a Play Permissions Declaration. |
| Notification access | Read alerts from an allowlist of payment/banking apps only. |
| `POST_NOTIFICATIONS` | Task reminders and detection alerts. |
| `SCHEDULE_EXACT_ALARM` | Reminders on the minute; degrades to approximate if denied. |

`SEND_SMS` is not requested and never will be.

## Privacy

Raw SMS and raw notification text **never leave the device**. Detections wait in
app-private storage until you confirm them. What syncs to Firestore is the
confirmed entry — amount, category, label, timestamp — under your own account.
The only text that leaves the device is what you type into AI chat.

Notification reading is an **allowlist**, not a blocklist: messaging, social and
mail apps are skipped without being opened. See
[PRIVACY_POLICY.md](PRIVACY_POLICY.md).

Deleting your account (**settings icon → Account → Delete my account**) removes
the auth record, every synced transaction and task, and all on-device data. It is
immediate and irreversible. The same instructions are published at
<https://hledger-ai-worker.guptahariom049.workers.dev/delete-account> for anyone
who no longer has the app installed.

## Development

```bash
flutter analyze
flutter test
```

The parser and classifier carry the bulk of the tests, because that is where a
bug silently books wrong numbers into someone's ledger. `test/upi_parser_test.dart`
and `test/notification_detection_test.dart` cover debits, credits, wallet
top-ups, cashback, promotional offers, card and RuPay-over-UPI flows, duplicates
and unsupported sources.

Detection accuracy is a moving target — banks reword alerts. If you hit a missed
or misread transaction, a failing test case in those files is the most useful
possible contribution.

## Contributing

Issues and pull requests are welcome. For detection bugs please include the
**alert wording** (with account numbers and amounts redacted) and the app it came
from — that is what makes a fix reproducible.

Do not include real API keys, keystores, or `google-services.json` in any issue
or PR.

## Notes

Auto-detection is a convenience, not a system of record. Cash is undetectable,
and some apps announce transactions in ways no parser can read. HLedger never
books an entry without your confirmation, and anything missed can be added by
hand.

## License

[MIT](LICENSE) © 2026 Hariom Gupta
