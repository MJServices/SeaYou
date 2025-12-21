# Database Migration - Bottles Tables

This file contains SQL queries to create the database tables for the SeaYou bottle messaging system.

## Instructions

1. Open your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Copy and paste the SQL queries below
4. Run each section separately to ensure no errors
5. Verify tables are created in the **Table Editor**

---

## Step 1: Create Tables

Run this query to create both `received_bottles` and `sent_bottles` tables:

```sql
-- Table: received_bottles
-- Stores all bottles received by users
CREATE TABLE received_bottles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Content
  content_type VARCHAR(20) NOT NULL CHECK (content_type IN ('text', 'voice', 'photo')),
  message TEXT,
  audio_url TEXT,
  photo_url TEXT,
  caption TEXT,

  -- Metadata
  mood VARCHAR(50),
  is_read BOOLEAN DEFAULT FALSE,
  is_replied BOOLEAN DEFAULT FALSE,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table: sent_bottles
-- Stores all bottles sent by users
CREATE TABLE sent_bottles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Content
  content_type VARCHAR(20) NOT NULL CHECK (content_type IN ('text', 'voice', 'photo')),
  message TEXT,
  audio_url TEXT,
  photo_url TEXT,
  caption TEXT,

  -- Metadata
  mood VARCHAR(50),
  is_delivered BOOLEAN DEFAULT FALSE,
  has_reply BOOLEAN DEFAULT FALSE,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Step 2: Create Indexes

Run this query to create indexes for better query performance:

```sql
-- Indexes for received_bottles
CREATE INDEX idx_received_bottles_receiver ON received_bottles(receiver_id);
CREATE INDEX idx_received_bottles_created ON received_bottles(created_at DESC);

-- Indexes for sent_bottles
CREATE INDEX idx_sent_bottles_sender ON sent_bottles(sender_id);
CREATE INDEX idx_sent_bottles_created ON sent_bottles(created_at DESC);
```

---

## Step 3: Enable Row Level Security (RLS)

Run this query to enable RLS on both tables:

```sql
-- Enable Row Level Security
ALTER TABLE received_bottles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sent_bottles ENABLE ROW LEVEL SECURITY;
```

---

## Step 4: Create RLS Policies

Run this query to create security policies:

```sql
-- RLS Policies for received_bottles
CREATE POLICY "Users can view their own received bottles"
  ON received_bottles FOR SELECT
  USING (auth.uid() = receiver_id);

CREATE POLICY "Users can insert received bottles"
  ON received_bottles FOR INSERT
  WITH CHECK (auth.uid() = receiver_id);

CREATE POLICY "Users can update their own received bottles"
  ON received_bottles FOR UPDATE
  USING (auth.uid() = receiver_id);

-- RLS Policies for sent_bottles
CREATE POLICY "Users can view their own sent bottles"
  ON sent_bottles FOR SELECT
  USING (auth.uid() = sender_id);

CREATE POLICY "Users can insert sent bottles"
  ON sent_bottles FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their own sent bottles"
  ON sent_bottles FOR UPDATE
  USING (auth.uid() = sender_id);
```

---

## Step 5: Insert Test Data (Optional)

Run this query to insert sample bottles for testing:

```sql
-- Insert test received bottles
-- Replace 'YOUR_USER_ID' with your actual user ID from auth.users table
INSERT INTO received_bottles (receiver_id, sender_id, content_type, message, mood, created_at) VALUES
  ('YOUR_USER_ID', NULL, 'text', 'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.', 'Curious', NOW() - INTERVAL '2 hours'),
  ('YOUR_USER_ID', NULL, 'text', 'Just wanted to share this beautiful moment with someone.', 'Happy', NOW() - INTERVAL '1 day'),
  ('YOUR_USER_ID', NULL, 'text', 'Hope you are having a wonderful day!', 'Excited', NOW() - INTERVAL '3 days');

-- Insert test sent bottles
INSERT INTO sent_bottles (sender_id, receiver_id, content_type, message, mood, created_at) VALUES
  ('YOUR_USER_ID', NULL, 'text', 'Hi. Prior to our previous conversation, I saw the river while the sun was setting and it was exactly as described.', 'Curious', NOW() - INTERVAL '1 hour'),
  ('YOUR_USER_ID', NULL, 'voice', NULL, 'Happy', NOW() - INTERVAL '2 days'),
  ('YOUR_USER_ID', NULL, 'photo', NULL, 'Excited', NOW() - INTERVAL '4 days');
```

**Note**: To get your user ID:

1. Go to **Authentication** > **Users** in Supabase dashboard
2. Copy your user's UUID
3. Replace `'YOUR_USER_ID'` in the queries above

---

## Verification

After running all queries, verify the setup:

1. **Check Tables**: Go to **Table Editor** and confirm both tables exist
2. **Check Indexes**: Go to **Database** > **Indexes** and verify indexes are created
3. **Check RLS**: Go to **Authentication** > **Policies** and verify policies exist
4. **Test Query**: Run a simple SELECT query:
   ```sql
   SELECT * FROM received_bottles WHERE receiver_id = auth.uid();
   ```

---

## Troubleshooting

- **Error: relation already exists**: Tables already created, skip Step 1
- **Error: policy already exists**: Policies already created, skip Step 4
- **Error: foreign key violation**: Make sure you're using a valid user ID from `auth.users` table
- **No data returned**: Check that you've inserted test data with your correct user ID

---

## Next Steps

After completing this migration:

1. The Flutter app will be updated to fetch data from these tables
2. The home screen will display real bottle counts and data
3. Empty states will show when no bottles exist

---

## Feeling System Schema (Conversations & Messages)

```sql
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_a_id uuid not null references auth.users(id) on delete cascade,
  user_b_id uuid not null references auth.users(id) on delete cascade,
  title text,
  exchanges_count int not null default 0,
  feeling_percent int not null default 0,
  exchange_open boolean not null default false,
  last_sender_id uuid,
  unlock_state jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.conversations enable row level security;
create policy conversations_rls_select on public.conversations for select
  using (auth.uid() = user_a_id or auth.uid() = user_b_id);
create policy conversations_rls_insert on public.conversations for insert
  with check (auth.uid() = user_a_id or auth.uid() = user_b_id);
create policy conversations_rls_update on public.conversations for update
  using (auth.uid() = user_a_id or auth.uid() = user_b_id);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('text','voice','image','quote','surprise')),
  text text,
  media_url text,
  created_at timestamptz not null default now()
);

alter table public.messages enable row level security;
create policy messages_rls_select on public.messages for select
  using (auth.uid() = (select user_a_id from public.conversations c where c.id = conversation_id)
       or auth.uid() = (select user_b_id from public.conversations c where c.id = conversation_id));
create policy messages_rls_insert on public.messages for insert
  with check (auth.uid() = sender_id
    and (auth.uid() = (select user_a_id from public.conversations c where c.id = conversation_id)
      or auth.uid() = (select user_b_id from public.conversations c where c.id = conversation_id)));

alter table public.user_preferences add column if not exists has_quote_feature boolean default true;
alter table public.user_preferences add column if not exists has_voice_feature boolean default true;
alter table public.user_preferences add column if not exists consent_photo_reveal boolean default false;
alter table public.profiles add column if not exists face_photo_url text;

create or replace function public.fn_update_feeling_on_message()
returns trigger as $$
declare
  a uuid;
  b uuid;
  ua jsonb;
  ub jsonb;
  new_exchanges int;
  new_percent int;
  new_unlock jsonb;
begin
  select user_a_id, user_b_id into a, b from public.conversations where id = new.conversation_id;

  if exists(select 1 from public.conversations c where c.id = new.conversation_id and c.last_sender_id is null) then
    update public.conversations set last_sender_id = new.sender_id, exchange_open = true where id = new.conversation_id;
  elsif exists(select 1 from public.conversations c where c.id = new.conversation_id and c.last_sender_id <> new.sender_id and c.exchange_open = true) then
    update public.conversations set exchanges_count = exchanges_count + 1, exchange_open = false, last_sender_id = new.sender_id where id = new.conversation_id;
  else
    update public.conversations set last_sender_id = new.sender_id, exchange_open = true where id = new.conversation_id;
  end if;

  select exchanges_count into new_exchanges from public.conversations where id = new.conversation_id;
  new_percent := least(100, new_exchanges * 10);

  select to_jsonb(up) from public.user_preferences up where up.user_id = a into ua;
  select to_jsonb(up) from public.user_preferences up where up.user_id = b into ub;

  new_unlock := coalesce((select unlock_state from public.conversations where id = new.conversation_id), '{}'::jsonb);
  if new_percent >= 25 then
    new_unlock := new_unlock || jsonb_build_object('quote_visible', coalesce((ua->>'has_quote_feature')::boolean, true) and coalesce((ub->>'has_quote_feature')::boolean, true));
  end if;
  if new_percent >= 50 then
    new_unlock := new_unlock || jsonb_build_object('voice_enabled', coalesce((ua->>'has_voice_feature')::boolean, true) and coalesce((ub->>'has_voice_feature')::boolean, true));
  end if;
  if new_percent >= 75 then
    new_unlock := new_unlock || jsonb_build_object('surprise_enabled', true);
  end if;
  if new_percent >= 100 then
    new_unlock := new_unlock || jsonb_build_object(
      'photo_reveal_unlocked',
      coalesce((ua->>'consent_photo_reveal')::boolean, false)
      and coalesce((ub->>'consent_photo_reveal')::boolean, false)
      and exists(select 1 from public.profiles p where p.id = a and p.face_photo_url is not null)
      and exists(select 1 from public.profiles p where p.id = b and p.face_photo_url is not null)
    );
  end if;

  update public.conversations set feeling_percent = new_percent, unlock_state = new_unlock, updated_at = now() where id = new.conversation_id;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_update_feeling_on_message on public.messages;
create trigger trg_update_feeling_on_message
after insert on public.messages
for each row execute procedure public.fn_update_feeling_on_message();
```
