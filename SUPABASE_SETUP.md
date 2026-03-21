# Supabase Setup Guide

Run these SQL commands in your Supabase SQL Editor to set up security and migrate data.

## Row Level Security (RLS) — REQUIRED

```sql
-- Enable RLS on both tables
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Users can only access their own transactions
CREATE POLICY "own_transactions" ON transactions
FOR ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can only access their own tasks
CREATE POLICY "own_tasks" ON tasks
FOR ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

## Migration: Map old credit/debit to income/expense

If your transactions table uses `category = 'credit'/'debit'` and doesn't have a `type` column:

```sql
-- Add type column if it doesn't exist
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS type text DEFAULT 'expense';

-- Migrate existing data
UPDATE transactions 
SET type = CASE 
  WHEN category = 'credit' THEN 'income'
  WHEN category = 'debit' THEN 'expense'
  ELSE 'expense'
END
WHERE type IS NULL OR type = 'expense';
```

## Expected Table Schemas

### transactions
| Column | Type | Notes |
|--------|------|-------|
| id | uuid (PK, auto) | |
| user_id | uuid (FK to auth.users) | |
| amount | numeric | |
| type | text | 'income' or 'expense' |
| category | text | 'Food', 'Transport', etc. |
| description | text | nullable |
| person | text | nullable, backward compat |
| created_at | timestamptz | auto |

### tasks
| Column | Type | Notes |
|--------|------|-------|
| id | uuid (PK, auto) | |
| user_id | uuid (FK to auth.users) | |
| title | text | |
| description | text | nullable |
| due_date | timestamptz | nullable |
| priority | text | 'low', 'medium', 'high' |
| is_completed | boolean | default false |
| reminder | boolean | default false |
| created_at | timestamptz | auto |
