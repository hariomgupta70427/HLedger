# HLedger - Smart Expense Tracker

*"Your Chat. Your Tasks. Your Transactions. Sorted."*

## Overview

HLedger is a Flutter-based AI-powered chat application that combines a To-Do manager and a Khaata Book (personal finance tracker) into one unified, chat-style interface. Users can type naturally in Hinglish or Hindi-English mixed format, and the app automatically detects the intent and stores data accordingly.

## Features

- 💬 **Chat Interface** - Natural language input for transactions and tasks
- 💰 **Khaata Book** - Track credits, debits, and balance
- ✅ **To-Do Management** - Task tracking with reminders
- 🤖 **AI Categorization** - Powered by Gemini 2.0 Flash Lite
- 🔔 **Local Notifications** - Task reminders and alerts
- 🎨 **Modern UI** - Clean Material 3 design

## Setup Instructions

### 1. Prerequisites
- Flutter SDK (>=3.8.0)
- Android Studio / VS Code
- Supabase account
- Google AI Studio account (for Gemini API)

### 2. Configuration

#### Supabase Setup
1. Create a new project at [supabase.com](https://supabase.com)
2. Get your project URL and anon key
3. Update `lib/core/constants/app_constants.dart`:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

#### Gemini API Setup
1. Get API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Update `lib/core/constants/app_constants.dart`:
   ```dart
   static const String geminiApiKey = 'YOUR_GEMINI_API_KEY';
   ```

#### Database Schema
Create these tables in your Supabase project:

```sql
-- Users table (auto-created by Supabase Auth)

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

-- Enable RLS
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can only see their own transactions" ON transactions
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can only see their own tasks" ON tasks
  FOR ALL USING (auth.uid() = user_id);
```

### 3. Installation

```bash
# Get dependencies
flutter pub get

# Generate JSON serialization files
flutter packages pub run build_runner build

# Run the app
flutter run
```

## Usage Examples

### Adding Transactions
- "1500 Kaif ko diye" → Adds ₹1500 debit to Kaif
- "2000 mile salary se" → Adds ₹2000 credit from salary

### Adding Tasks
- "CN ka assignment kal tak karna hai" → Adds task with tomorrow's due date
- "Meeting 3 baje" → Adds meeting task for 3 PM

## Project Structure

```
lib/
├── core/
│   ├── constants/     # App constants and configuration
│   └── theme/         # App theme and styling
├── data/
│   └── services/      # External services (Gemini, Notifications)
├── features/
│   ├── auth/          # Authentication screens
│   ├── dashboard/     # Main dashboard and profile
│   └── transactions/  # Transaction and task management
└── main.dart
```

## Tech Stack

- **Framework**: Flutter
- **Backend**: Supabase
- **AI**: Gemini 2.0 Flash Lite
- **Notifications**: flutter_local_notifications
- **State Management**: Provider
- **UI**: Material 3

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.