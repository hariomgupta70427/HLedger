# HLedger - Smart Expense Tracker

*"Your Chat. Your Tasks. Your Transactions. Sorted."*

<p align="center">
  <img src="assets/icons/hledger_icon.png" alt="HLedger Logo" width="120"/>
</p>

## 📱 Overview

HLedger is a Flutter-based AI-powered chat application that combines a **To-Do Manager** and a **Khaata Book** (personal finance tracker) into one unified, chat-style interface. Users can type naturally in Hinglish or Hindi-English mixed format, and the app automatically detects the intent and stores data accordingly.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 💬 **Chat Interface** | Natural language input for transactions and tasks |
| 💰 **Khaata Book** | Track credits, debits, and balance with detailed history |
| ✅ **To-Do Management** | Task tracking with reminders and notifications |
| 🤖 **AI Categorization** | Powered by OpenRouter API (Gemma 2 9B) |
| 🔔 **Local Notifications** | Task reminders with exact alarm scheduling |
| � **Dark Mode** | System-aware theme switching |
| 🔐 **Google Sign-In** | Secure OAuth authentication via Supabase |
| 📱 **Session Persistence** | Stay logged in across app restarts |

---

## 🛠️ Tech Stack

- **Framework**: Flutter 3.8+
- **Backend**: Supabase (Auth + Database)
- **AI**: OpenRouter API (google/gemma-2-9b-it:free)
- **Notifications**: flutter_local_notifications
- **State Management**: Provider
- **UI**: Material 3 with custom theming

---

## 📋 Prerequisites

- Flutter SDK (>=3.8.0)
- Android Studio / VS Code
- Android device or emulator (minSdk 21+)
- Accounts on:
  - [Supabase](https://supabase.com)
  - [OpenRouter](https://openrouter.ai) (for AI features)

---

## 🚀 Setup Instructions

### Step 1: Clone the Repository

```bash
git clone https://github.com/hariomgupta70427/HLedger.git
cd HLedger
```

### Step 2: Configure API Credentials

1. **Copy the example configuration file:**
   ```bash
   cp lib/core/constants/app_constants.dart.example lib/core/constants/app_constants.dart
   ```

2. **Fill in your credentials in `app_constants.dart`:**

   ```dart
   // Supabase Configuration
   static const String supabaseUrl = 'https://your-project.supabase.co';
   static const String supabaseAnonKey = 'your-anon-key-here';

   // OpenRouter API (for AI Chat)
   static const String openRouterApiKey = 'sk-or-v1-your-key-here';
   static const String openRouterModel = 'google/gemma-2-9b-it:free';
   ```

### Step 3: Supabase Setup

#### 3.1 Create Database Tables

Run these SQL commands in Supabase SQL Editor:

```sql
-- Transactions table
CREATE TABLE transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  person TEXT NOT NULL,
  amount DECIMAL NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('credit', 'debit')),
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  description TEXT
);

-- Tasks table
CREATE TABLE tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  due_date TIMESTAMP WITH TIME ZONE,
  completed BOOLEAN DEFAULT FALSE,
  reminder BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- RLS Policies (users can only access their own data)
CREATE POLICY "Users can manage own transactions" ON transactions
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own tasks" ON tasks
  FOR ALL USING (auth.uid() = user_id);
```

#### 3.2 Configure Google OAuth

1. Go to **Supabase Dashboard** → **Authentication** → **Providers**
2. Enable **Google** provider
3. Add your Google OAuth credentials (Client ID & Secret)

#### 3.3 Configure Redirect URLs

1. Go to **Authentication** → **URL Configuration**
2. Add this **Redirect URL**:
   ```
   io.supabase.hledger://login-callback
   ```
   > ⚠️ This is CRITICAL for Google Sign-In to work correctly!

### Step 4: Install Dependencies

```bash
flutter pub get
```

### Step 5: Run the App

```bash
# Development
flutter run

# Specific device
flutter run -d <device_id>
```

---

## 📦 Building for Production

### Generate Release Keystore (First Time Only)

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### Configure Signing

Create `android/key.properties`:
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=upload
storeFile=upload-keystore.jks
```

### Build Release APK

```bash
# Clean build with split APKs (recommended)
flutter clean
flutter pub get
flutter build apk --release --split-per-abi

# Output locations:
# - build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (~31 MB)
# - build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk (~28 MB)
```

### Install on Device

```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 🔧 Configuration Reference

| File | Purpose |
|------|---------|
| `lib/core/constants/app_constants.dart` | API keys and configuration (gitignored) |
| `android/key.properties` | Release signing credentials (gitignored) |
| `android/app/upload-keystore.jks` | Release keystore file (gitignored) |

---

## 📱 Usage Examples

### Adding Transactions (via Chat)
```
"1500 Kaif ko diye" → Adds ₹1500 debit to Kaif
"2000 mile salary se" → Adds ₹2000 credit from salary
"500 chai ke liye" → Adds ₹500 miscellaneous debit
```

### Adding Tasks
```
"CN ka assignment kal tak karna hai" → Task with tomorrow's deadline
"Meeting 3 baje" → Task for 3 PM today
"Reminder: electricity bill Friday ko" → Task with Friday reminder
```

---

## 📁 Project Structure

```
HLedger/
├── android/
│   ├── app/
│   │   ├── src/main/kotlin/com/hariverse/hledger/
│   │   │   └── MainActivity.kt
│   │   ├── build.gradle.kts
│   │   └── upload-keystore.jks (gitignored)
│   └── key.properties (gitignored)
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart (gitignored)
│   │   │   └── app_constants.dart.example
│   │   └── theme/
│   ├── data/services/
│   │   └── gemini/gemini_service.dart (OpenRouter integration)
│   ├── features/
│   │   └── transactions/chat_screen.dart
│   ├── models/
│   ├── providers/
│   ├── services/
│   │   ├── supabase_service.dart
│   │   └── notification_service.dart
│   └── main.dart
├── assets/
│   └── icons/hledger_icon.png
├── pubspec.yaml
└── README.md
```

---

## 🔐 Security Notes

> ⚠️ **NEVER commit credentials to Git!**

The following files are already in `.gitignore`:
- `lib/core/constants/app_constants.dart`
- `android/key.properties`
- `android/app/upload-keystore.jks`
- `google-services.json`

---

## 📄 License

This project is licensed under the MIT License.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
