<div align="center">

<img src="assets/icon/app_icon.png" alt="HLedger Logo" width="100" height="100" style="border-radius: 22px"/>

# HLedger

**Track money and tasks — just by talking.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-54C5F8?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![OpenRouter](https://img.shields.io/badge/AI-OpenRouter-6C63FF)](https://openrouter.ai)
[![License](https://img.shields.io/badge/License-MIT-00D68F)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hariomgupta70427/HLedger?color=FF4757)](https://github.com/hariomgupta70427/HLedger/releases)

[Download APK](https://github.com/hariomgupta70427/HLedger/releases/latest) · [Report Bug](https://github.com/hariomgupta70427/HLedger/issues) · [Request Feature](https://github.com/hariomgupta70427/HLedger/discussions)

</div>

---

## The idea

Most finance apps make you fill forms. HLedger doesn't.

You just talk to it — _"spent 200 on lunch"_, _"remind me to pay rent tomorrow"_ — and it figures out the rest. Entries go straight to your Khaata. Tasks show up with reminders. No dropdowns, no manual categorization, no friction.

Built for people who want to track their money without thinking too hard about tracking their money.

---

## What's inside

```
📊  Dashboard    — spending charts, weekly trends, quick stats
📒  Khaata       — income/expense ledger, real-time sync
💬  Chat         — AI assistant that actually does things
✅  Tasks        — to-dos with reminders, even when app is closed
```

---

## Screenshots

> Add screenshots here — Dashboard / Khaata / Chat / Tasks

---

## Features

### Chat that works like WhatsApp
Type naturally in Hindi, English, or Hinglish. The AI understands what you mean and acts on it — no confirmation dialogs, no extra steps.

```
You:       spent 350 on groceries
HLedger:   Done ✓ ₹350 groceries added.

You:       remind me to pay electricity bill friday
HLedger:   Added 📝 Electricity bill — Friday.
```

### Khaata (Expense Ledger)
- Income and expense tracking with category icons
- Balance summary — this month or all time
- Real-time updates when Chat adds an entry
- Swipe left to delete
- Pull to refresh

### Tasks
- Add via Chat or manually
- Set due dates and reminders (fires even when app is closed)
- Priority: Low / Medium / High
- Filter: All / Active / Completed
- Swipe right to complete, swipe left to delete
- Overdue tasks show in red

### Dashboard
- Good morning greeting (time-aware)
- Weekly spending bar chart
- Category breakdown
- Quick stats: transactions, tasks done, pending, net balance

### Navigation
- Instagram-style swipe between tabs
- Floating pill bottom nav

---

## Tech Stack

| Layer | What |
|---|---|
| Framework | Flutter 3.x (Dart) |
| Backend | Supabase (PostgreSQL + Auth + Realtime) |
| AI | OpenRouter — free tier, Llama 4 + Mistral |
| State | Provider |
| Notifications | flutter_local_notifications |
| Animations | flutter_animate |
| Local storage | SharedPreferences (chat history) |

---

## Getting Started

### Prerequisites

- Flutter 3.x
- Dart 3.x
- A Supabase project
- An OpenRouter API key (free at [openrouter.ai](https://openrouter.ai))

### Setup

**1. Clone the repo**
```bash
git clone https://github.com/hariomgupta70427/HLedger.git
cd HLedger
```

**2. Install dependencies**
```bash
flutter pub get
```

**3. Set up environment**
```bash
cp .env.example .env
```

Fill in your values:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
OPENROUTER_KEY=sk-or-your-key
```

**4. Set up Supabase**

Run the SQL in `SUPABASE_SETUP.md` in your Supabase SQL Editor.
This creates the tables and Row Level Security policies.

**5. Run**
```bash
flutter run --dart-define=SUPABASE_URL=xxx \
            --dart-define=SUPABASE_ANON_KEY=xxx \
            --dart-define=OPENROUTER_KEY=xxx
```

### Building a release APK

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_key \
  --dart-define=OPENROUTER_KEY=your_key
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Project Structure

```
lib/
├── main.dart                  # Entry point, auth routing
├── screens/
│   ├── dashboard_screen.dart  # Home tab with analytics
│   ├── khaata_screen.dart     # Expense ledger
│   ├── chat_screen.dart       # AI chat interface
│   ├── tasks_screen.dart      # To-do list
│   └── profile_screen.dart    # Settings, logout
├── services/
│   ├── supabase_service.dart  # All database operations
│   ├── gemini_service.dart    # OpenRouter AI calls
│   ├── notification_service.dart
│   └── supabase_keep_alive.dart
├── models/
│   ├── transaction.dart
│   └── task.dart
├── widgets/
│   ├── transaction_card.dart
│   ├── shimmer_skeleton.dart
│   ├── typing_indicator.dart
│   └── balance_summary.dart
├── utils/
│   ├── app_theme.dart
│   ├── app_constants.dart
│   ├── retry_helper.dart
│   └── input_validator.dart
└── providers/
    └── app_provider.dart
```

---

## Database Schema

Two tables in Supabase:

**transactions**
| Column | Type | Notes |
|---|---|---|
| id | uuid | Primary key, auto-generated |
| user_id | uuid | References auth.users |
| amount | numeric | |
| type | text | `income` or `expense` |
| category | text | Food, Transport, etc. |
| description | text | |
| created_at | timestamptz | Default: now() |

**tasks**
| Column | Type | Notes |
|---|---|---|
| id | uuid | Primary key, auto-generated |
| user_id | uuid | References auth.users |
| title | text | |
| description | text | Nullable |
| due_date | date | Nullable |
| reminder_date_time | timestamptz | Nullable |
| priority | text | `low`, `medium`, `high` |
| is_completed | boolean | Default: false |
| created_at | timestamptz | Default: now() |

Row Level Security is enabled on both tables — users can only access their own data.

---

## Supabase Free Tier

Built to stay comfortably within Supabase's free limits, even with 30–50 users:

- Chat history is stored locally (SharedPreferences) — no database reads/writes
- AI calls go through OpenRouter, not Supabase
- Transactions and tasks are cached locally for 5 minutes
- Keep-alive ping runs every 10 minutes (prevents project pausing)
- Only CRUD operations hit Supabase

---

## Security

- API keys are baked at build time via `--dart-define` — not in source code, not in `.env` committed to git
- Row Level Security enforced at the database level
- All user input is sanitized before being sent to the AI
- HTTPS only — cleartext traffic is blocked in the Android network config
- Release APK has code minification and obfuscation enabled

---

## Roadmap

- [ ] iOS support
- [ ] Export to CSV / PDF
- [ ] Recurring transactions
- [ ] UPI transaction detection (auto-import)
- [ ] Budget limits with alerts
- [ ] Multi-currency support
- [ ] Widget for home screen balance

---

## Contributing

Issues and PRs are welcome. If you're planning something big, open a discussion first so we're on the same page.

```bash
git checkout -b feature/your-feature
git commit -m "feat: describe your change"
git push origin feature/your-feature
```

---

## License

MIT — do what you want, just don't remove the attribution.

---

<div align="center">

Built by [Hariom Gupta](https://hariomgupta.vercel.app) · New Delhi, India

</div>
