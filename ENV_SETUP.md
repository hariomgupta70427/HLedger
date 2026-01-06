# 🔧 Environment Setup Guide

Complete guide for configuring all APIs and credentials for HLedger development and production.

---

## 📋 Required Accounts & Services

| Service | Purpose | Sign Up |
|---------|---------|---------|
| **Supabase** | Backend, Auth, Database | [supabase.com](https://supabase.com) |
| **OpenRouter** | AI Chat (Gemma 2 9B) | [openrouter.ai](https://openrouter.ai) |
| *Optional: Google Cloud* | Native Google Sign-In | [console.cloud.google.com](https://console.cloud.google.com) |

---

## 🔐 Step 1: Supabase Setup

### 1.1 Create Project

1. Go to [supabase.com](https://supabase.com) and sign in
2. Click **New Project**
3. Choose organization and enter project details
4. Wait for project to initialize

### 1.2 Get API Credentials

1. Go to **Project Settings** → **API**
2. Copy these values:
   - **Project URL**: `https://your-project-id.supabase.co`
   - **anon public key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

### 1.3 Enable Google OAuth

1. Go to **Authentication** → **Providers**
2. Enable **Google**
3. Enter your Google OAuth credentials:
   - **Client ID**: From Google Cloud Console
   - **Client Secret**: From Google Cloud Console

### 1.4 Configure Redirect URLs

> ⚠️ **CRITICAL for mobile login to work!**

1. Go to **Authentication** → **URL Configuration**
2. In **Redirect URLs**, add:
   ```
   io.supabase.hledger://login-callback
   ```
3. Click **Save**

---

## 🤖 Step 2: OpenRouter API Setup

### 2.1 Get API Key

1. Go to [openrouter.ai](https://openrouter.ai)
2. Sign in with Google/GitHub
3. Go to **Keys** → **Create Key**
4. Copy the key: `sk-or-v1-...`

### 2.2 Model Selection

The app uses `google/gemma-2-9b-it:free` by default. You can change this in `app_constants.dart`:

```dart
static const String openRouterModel = 'google/gemma-2-9b-it:free';
```

**Available free models:**
- `google/gemma-2-9b-it:free` (Recommended)
- `meta-llama/llama-3.1-8b-instruct:free`
- `mistralai/mistral-7b-instruct:free`

---

## 📁 Step 3: Configure App

### 3.1 Create Configuration File

```bash
cp lib/core/constants/app_constants.dart.example lib/core/constants/app_constants.dart
```

### 3.2 Fill in Credentials

Edit `lib/core/constants/app_constants.dart`:

```dart
class AppConstants {
  static const String appName = 'HLedger';
  static const String tagline = 'Your Chat. Your Tasks. Your Transactions. Sorted.';
  static const String splashSubtext = 'Smart Ledger for Smarter You';

  // ==================== SUPABASE ====================
  // Get from: Supabase Dashboard → Project Settings → API
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

  // ==================== OPENROUTER API ====================
  // Get from: https://openrouter.ai/keys
  static const String openRouterApiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String openRouterApiKey = 'sk-or-v1-your-key-here';
  static const String openRouterModel = 'google/gemma-2-9b-it:free';

  // ==================== DATABASE TABLES ====================
  static const String usersTable = 'users';
  static const String transactionsTable = 'transactions';
  static const String tasksTable = 'tasks';

  // ==================== NOTIFICATIONS ====================
  static const String notificationChannelId = 'hledger_reminders';
  static const String notificationChannelName = 'Task Reminders';
}
```

---

## 🔑 Step 4: Android Release Signing (Production Only)

### 4.1 Generate Keystore

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Enter a strong password when prompted.

### 4.2 Create key.properties

Create `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

### 4.3 Backup Keystore

> ⚠️ **CRITICAL: Store these securely!**

Backup these files somewhere safe:
- `android/app/upload-keystore.jks`
- `android/key.properties`

**If you lose the keystore, you cannot update your app on Google Play!**

---

## ✅ Verification Checklist

Before running the app, verify:

- [ ] `lib/core/constants/app_constants.dart` exists with real values
- [ ] Supabase project is created with tables
- [ ] Supabase redirect URL `io.supabase.hledger://login-callback` is added
- [ ] Google OAuth is enabled in Supabase
- [ ] OpenRouter API key is valid
- [ ] (Production) Keystore and key.properties are configured

---

## 🚨 Security Reminders

| File | Status | Note |
|------|--------|------|
| `lib/core/constants/app_constants.dart` | ❌ gitignored | Contains API keys |
| `android/key.properties` | ❌ gitignored | Contains keystore passwords |
| `android/app/upload-keystore.jks` | ❌ gitignored | Release signing key |
| `google-services.json` | ❌ gitignored | Firebase config (if used) |

**Never commit these files to Git!**

---

## 🆘 Troubleshooting

### "Google Sign-In redirects to localhost"
→ Add `io.supabase.hledger://login-callback` to Supabase Redirect URLs

### "User logged out after app close"
→ Session persistence is automatic; ensure Supabase is properly initialized

### "AI chat not responding"
→ Check OpenRouter API key is valid and has credits

### "Build fails with signing error"
→ Verify `key.properties` path and keystore file exists
