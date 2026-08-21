# Firebase Setup

HLedger uses **Firebase Authentication** for sign-in and **Cloud Firestore** for
sync. Both sit on the Spark (free) plan, which has no idle timeout — there is
nothing to resume, ever.

Everything below is done once, in the console, and takes about five minutes.
The build will not compile until step 4 puts `google-services.json` in place —
the Google Services Gradle plugin fails the build when the file is absent.

---

## 1. Create the project

1. Open [console.firebase.google.com](https://console.firebase.google.com) → **Add project**.
2. Name it `HLedger`.
3. Google Analytics is optional and unused by the app — skip it.

## 2. Enable the sign-in providers

**Build → Authentication → Get started**, then enable both:

| Provider | Notes |
|---|---|
| **Email/Password** | Leave passwordless sign-in off. |
| **Google** | Pick a support email when prompted. |

## 3. Create the database

1. **Build → Firestore Database → Create database**.
2. Choose **production mode** — it starts closed, and step 3.3 opens exactly the
   paths the app needs. Test mode would leave every document world-readable
   until its 30-day timer expired.
3. Region **`asia-south1`** (Mumbai) for Indian users. This is permanent; a
   region change means a new project.
4. Open the **Rules** tab, replace the contents with [`firestore.rules`](firestore.rules)
   from this repo, and click **Publish**:

   ```
   rules_version = '2';

   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```

   Every document the app writes lives under `users/{uid}`, so this single uid
   comparison covers transactions, tasks, and anything added later.

No collections need creating by hand — Firestore materialises
`users/{uid}/transactions` and `users/{uid}/tasks` on first write.

## 4. Register the Android app

1. **Project settings → Your apps → Add app → Android**.
2. Android package name: **`com.hariverse.hledger`** (must match exactly —
   `android/app/build.gradle.kts`). Nickname and debug SHA-1 can wait.
3. Download **`google-services.json`** and drop it into **`android/app/`**.
   It is already gitignored.

## 5. Register both SHA-1 fingerprints

> Google Sign-In fails silently without this — the button appears to do nothing.
> Email/password works fine, which makes it easy to misread as a code bug.

Still in **Project settings → Your apps → HLedger (Android) → Add fingerprint**.
Get the values from:

```bash
# Debug (every dev machine has its own — add each one)
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" \
  -alias androiddebugkey -storepass android -keypass android

# Release (the upload key that signs Play Store builds)
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
```

Copy the `SHA1:` line from each and add both. Then **re-download
`google-services.json`** — the fingerprints are baked into it, so the copy from
step 4 is already stale.

## 6. Build

```bash
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

`dart_defines.json` carries only `AI_PROXY_URL` — the public address of the
Cloudflare AI Worker, not a secret. No provider API key ships in the app; see
[ENV_SETUP.md](ENV_SETUP.md).
Firebase needs no dart-define — its config travels in `google-services.json`.

---

## Verifying it works

Run through this in order; each step exercises a different path.

1. **Sign up** with an email → a verification mail arrives.
2. **Sign out**, then **Sign in with Google** → lands on the dashboard without
   opening a browser. If it silently returns, revisit step 5.
3. **Add a transaction** → appears instantly, and shows up in the console under
   `users/{your-uid}/transactions`.
4. **Add a task with a reminder** → the notification fires at its time.
5. **Force-quit and relaunch** → data is still there.
6. **Turn on airplane mode, add a transaction** → it appears immediately.
   Re-enable the network → it syncs to the console within seconds.

Step 6 is the offline path, and it is the one worth checking twice.

---

## Free-tier headroom

Spark limits, per day unless noted:

| Resource | Limit | What HLedger uses |
|---|---|---|
| Document reads | 50,000 | ~1 per transaction per session — listeners bill only *changed* documents after the first load, so a refresh costs nothing |
| Document writes | 20,000 | 1 per entry created, edited, or deleted |
| Storage | 1 GiB total | A ledger row is well under 1 KB |
| Auth monthly actives | 50,000 | 1 per user |

Chat history and pending detected transactions never touch Firestore — they live
in SharedPreferences on the device. AI calls go to Groq. So the only traffic is
ledger and task CRUD, which leaves the daily quotas essentially untouched at the
scale this app is built for.

---

## Troubleshooting

**`File google-services.json is missing`**
Step 4 was skipped, or the file landed in the wrong directory. It belongs at
`android/app/google-services.json`, not `android/`.

**Google Sign-In closes and returns to the login screen**
The SHA-1 for the keystore signing this build is not registered. Debug and
release keys are different — add both (step 5), then re-download the JSON.

**`PERMISSION_DENIED: Missing or insufficient permissions`**
The rules from step 3.4 were never published, or the app is writing while signed
out. Check the **Rules** tab shows the `users/{userId}` match.

**Writes appear locally, then vanish**
The local cache accepted the write and the server rejected it — almost always a
rules mismatch. The rejection is logged; check `flutter logs` for the
`Firestore could not …` line.

**`No matching client found for package name`**
The package in `google-services.json` differs from `applicationId` in
`android/app/build.gradle.kts`. Both must read `com.hariverse.hledger`.
