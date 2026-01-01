# Environment Setup Guide

This document explains how to configure credentials for local development.

## Credentials Required

This project uses the following external services that require API credentials:

### 1. Supabase (Backend & Authentication)
- **URL**: Create account at https://supabase.com
- **Steps**:
  1. Create a new project
  2. Go to Project Settings → API
  3. Copy the `Project URL` and `anon public key`
  4. Add to `lib/core/constants/app_constants.dart`

### 2. Google Generative AI (Gemini)
- **API Key**: Get from https://console.cloud.google.com/
- **Steps**:
  1. Create a Google Cloud project
  2. Enable the Generative Language API
  3. Create an API key in the credentials section
  4. Add to `lib/core/constants/app_constants.dart`

## Setup Instructions

1. **Copy the example file**:
   ```bash
   cp lib/core/constants/app_constants.dart.example lib/core/constants/app_constants.dart
   ```

2. **Fill in your credentials** in `lib/core/constants/app_constants.dart`:
   ```dart
   static const String supabaseUrl = 'your_url_here';
   static const String supabaseAnonKey = 'your_key_here';
   static const String geminiApiKey = 'your_api_key_here';
   ```

3. **Never commit credentials** - The `.gitignore` file already excludes `app_constants.dart`

## Android Setup

For Android development, update `android/local.properties`:
```
sdk.dir=/path/to/android/sdk
flutter.sdk=/path/to/flutter/sdk
```

This file is also excluded from Git.

## Important Security Notes

⚠️ **NEVER** commit credentials, API keys, or sensitive information to version control.

✅ Always use `.env` files or configuration files that are in `.gitignore` for sensitive data.

✅ Rotate API keys immediately if they are accidentally exposed.

✅ Use environment-specific configurations for development, staging, and production.
