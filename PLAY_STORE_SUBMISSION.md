# Play Store Submission — HLedger

Everything preparable from the repository side. Items marked **YOU** can only be
done in Play Console or on a Google account.

Package `com.hariverse.hledger` · versionName `1.0.0` · versionCode `1`
minSdk 24 · compileSdk/targetSdk 36
Artifact: `build/app/outputs/bundle/release/app-release.aab`

---

## 1. Final permission list and purpose

Verified against the **merged** manifest of the release build, not the source.

| Permission | Level | Purpose | Declaration |
| --- | --- | --- | --- |
| `INTERNET` | Normal | Firestore sync, Firebase Auth, AI proxy | — |
| `ACCESS_NETWORK_STATE` | Normal | Offline handling | — |
| `POST_NOTIFICATIONS` | Runtime | Task reminders, detection alerts | — |
| `VIBRATE` | Normal | Reminder vibration | — |
| `RECEIVE_BOOT_COMPLETED` | Normal | Re-arm reminders after restart | — |
| `SCHEDULE_EXACT_ALARM` | Special | Reminders on the minute; degrades to inexact if denied | — |
| `READ_SMS` | **Restricted** | Detect transactions from bank SMS | **Required — see §2** |
| `RECEIVE_SMS` | **Restricted** | Same, for incoming messages | **Required — see §2** |
| `BIND_NOTIFICATION_LISTENER_SERVICE` | Special (service) | Detect transactions from payment-app notifications | No form required |
| `WAKE_LOCK`, `FOREGROUND_SERVICE` | Normal | Injected by `flutter_local_notifications` / `another_telephony` | — |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | Normal | Injected by Credential Manager (Google Sign-In) | — |
| `READ_GSERVICES` | Signature | Injected by Firebase | — |
| `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Signature (own) | Self-scoped, injected by AndroidX for runtime-registered receivers | — |

**Deliberately removed** — do not re-add without re-reading policy:

- `USE_EXACT_ALARM` — Play limits it to apps whose *core* function is an alarm
  clock, timer or calendar. HLedger is a ledger.
- `USE_FULL_SCREEN_INTENT` — was declared but never used.
- `ACCESS_COARSE_LOCATION` — injected by `another_telephony`; stripped with
  `tools:node="remove"`. The app uses no location, and leaving it in would have
  contradicted the privacy policy and pulled location into Data Safety.
- `SEND_SMS` — never.

## 2. SMS Permissions Declaration — the one real submission risk

Per the current policy
(<https://support.google.com/googleplay/android-developer/answer/10208820>),
**"SMS-based financial transactions (e.g., UPI)"** and **"SMS-based money
management"** are both named exceptions covering `READ_SMS` *and* `RECEIVE_SMS`.
HLedger's use case is named in the policy.

**But read this before filing.** The exception also requires that the permission
is core — *"without which, the app is broken or rendered unusable"* — and that
*"there's currently no alternative method to provide the core functionality."*
HLedger now has a working notification-based alternative and functions fully
without SMS. A reviewer can reasonably conclude the exception does not apply.
This is a genuine risk, not a formality.

HLedger does satisfy the specific anti-abuse clause: *"personal loans or budgeting
apps may not exfiltrate or share non-financial or personal SMS history"* — no SMS
content leaves the device.

**YOU — Play Console → App content → Sensitive app permissions:**

1. Core functionality: detecting the user's own bank/UPI transactions from
   transactional SMS, to create entries they confirm.
2. Why notifications are insufficient: many Indian banks announce a transaction
   only by SMS.
3. Scope: body and sender read only to extract amount, direction, counterparty,
   reference. Messages from ordinary phone numbers are discarded unparsed. OTP
   messages are rejected before any figure is extracted.
4. Raw SMS never leaves the device — no server, no analytics, not to the AI proxy.
5. Consent: prominent disclosure shown before Android's prompt.
6. Attach a **demo video**: disclosure → consent → detection → review → save.

Publishing is blocked while these are declared but undeclared: *"Apps that fail
to meet policy requirements or lack a Permissions Declaration Form may be removed
from Google Play."*

**Fallback if rejected:** remove the two `uses-permission` lines and the
`IncomingSmsReceiver` from the manifest and ship notification-only. That path
needs no restricted permission and still detects payments with the app closed,
because capture is native and disk-backed. See `PLAY_STORE_COMPLIANCE.md` §c2.

Also make SMS detection read as **core** in the store listing — describe
automatic bank-SMS capture as a headline feature, not a nice-to-have.

## 3. Data Safety — from actual implementation

**Collected and transmitted off device**

| Data | Purpose | Shared | Optional |
| --- | --- | --- | --- |
| Email address | Account management, auth | No | No |
| Financial info — confirmed transaction amount, category, label, timestamp | App functionality | No | No |
| Tasks / notes text | App functionality | No | No |
| AI chat message text | App functionality — sent to Groq, or Gemini on failover | Yes, to the AI provider | Yes (chat is optional) |

**Processed on device only, never transmitted**

- Raw SMS content
- Raw notification content
- Pending (unconfirmed) detections
- Chat history

**Answers:** encrypted in transit — **Yes** (HTTPS throughout). Users can request
deletion — **Yes**, and supply the URL from §4b; Play asks about in-app deletion
separately, which HLedger also has. Data collection optional — partly (detection
sources and chat are optional; an account is not).

On-device storage is app-private (`MODE_PRIVATE`) but **not** separately
encrypted by the app — it relies on Android's own full-disk encryption. Do not
claim app-level encryption at rest anywhere in the listing.

Do **not** declare Location. It was removed from the merged manifest.

## 4. Privacy policy

`PRIVACY_POLICY.md` is accurate and now publishable (it was previously gitignored,
which contradicted Play's public-URL requirement).

Hosted and live at <https://hledger-privacy-policy.guptahariom049.workers.dev/>.
The contact email is already filled in.

**YOU:** enter that URL in Play Console → App content → Privacy policy, and
confirm it loads in a private window with no login.

## 4b. Account deletion — required by Play

Google Play requires both an in-app deletion route and a publicly reachable web
URL that works without installing the app. Both exist, and both have been
tested on the final release build.

**In-app:** settings icon (Home tab) → **Account** → **Delete my account**, behind
a two-step confirmation. It deletes Firestore data first, then the auth record —
that order matters, because deleting the account first would strand the user's
financial data where nobody can read or erase it. Local data (pending detections,
chat history, preferences) is wiped too.

**Web URL to enter in Play Console → App content → Data deletion:**
<https://hledger-ai-worker.guptahariom049.workers.dev/delete-account>

Verified on the release build: the Account screen is reachable, deletion
completes, and the Firebase auth record and Firestore documents are both gone
afterwards. Subcollections are deleted in pages of 400 (the batch limit is 500),
so a large ledger cannot silently leave documents behind.

The Account screen also surfaces what was previously invisible: name, email,
sign-in method, email-verified status and member-since date.

**Known limitation, by design:** Firebase refuses to delete an account whose
sign-in is not recent. When that happens the app reports it plainly and tells the
user to sign in again — the server data is already gone at that point, and the
message says so. It does not fail silently.

## 5. App access instructions

**YOU — Play Console → App content → App access.** The app is behind sign-in, so
reviewers need credentials. Create a throwaway account (email/password, not
Google) with a few sample transactions and tasks, and provide it.

Add this note: *"Automatic transaction detection requires a real bank SMS or
payment-app notification and cannot be triggered on demand. The review inbox and
manual/chat entry demonstrate the full flow. A demo video is attached to the SMS
permissions declaration."*

## 6. Store listing material still needed

**YOU** — none of this can come from the repo: app icon 512×512, feature graphic
1024×500, at least 2 phone screenshots (4–8 recommended), short description
(80 chars), full description (4000 chars) that names SMS-based transaction
detection as core, content rating questionnaire, target audience, ads declaration
(**No**), category (Finance).

## 7. Remaining manual Play Console steps

1. Create the app; upload `app-release.aab`.
2. **File the SMS Permissions Declaration** (§2) — blocks publishing.
3. Complete the **Data Safety** form (§3).
4. Host the privacy policy and enter its URL (§4).
4b. Enter the **data deletion URL** from §4b under App content → Data deletion.
5. Provide **App access** credentials (§5).
6. Content rating questionnaire.
7. Store listing assets (§6).
8. Confirm Play App Signing is enabled and keep `upload-keystore.jks` backed up
   somewhere safe — losing it means you cannot ship updates.

## 8. Release verification

Measured against the artifacts that will be uploaded, not the source.

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test` | 88 passing |
| `targetSdkVersion` in merged manifest | **36** |
| `minSdkVersion` in merged manifest | **24** (`maxOf(flutter.minSdkVersion, 23)`) |
| `android:debuggable` in release manifest | absent |
| Release signer | `CN=HLedger, OU=HariVerse` — upload keystore, not the debug key |
| Provider keys in `libapp.so` (`gsk_`, `AIzaSy`, `sk-or-v1`) | 0 occurrences, all ABIs |
| Account-deletion strings in the AAB's `libapp.so` | present |
| Secrets in tracked files | none |

**Signing scheme note.** The APK verifies under APK Signature Scheme v2 only, not
v3. That is fine for upload — Play App Signing re-signs the artifact it
distributes — so the upload key's scheme is not what reaches devices.

**Build caveat that bit this project twice.** Gradle will happily reuse a stale
Dart AOT snapshot, producing a build that succeeds while missing your newest
code. A release build finishing suspiciously fast (well under a minute) is the
tell. Confirm a new feature actually shipped by extracting `libapp.so` from the
artifact and grepping it for a string that only the new code contains — a green
build log is not evidence.
