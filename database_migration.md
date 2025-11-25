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
