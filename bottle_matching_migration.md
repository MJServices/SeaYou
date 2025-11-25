# Bottle Matching System - Database Migration

This migration adds all necessary tables and columns for the intelligent bottle matching system with "floating in the sea" UX.

## Step 1: Update Profiles Table

Add matching-related fields to track user activity and bottle counts:

```sql
-- Add matching and activity tracking fields
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_active TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bottles_received_today INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bottles_sent_today INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_bottles_received INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_bottles_sent INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS receive_bottles BOOLEAN DEFAULT TRUE;

-- Create indexes for matching queries
CREATE INDEX IF NOT EXISTS idx_profiles_matching ON profiles(interested_in, is_active, receive_bottles);
CREATE INDEX IF NOT EXISTS idx_profiles_last_active ON profiles(last_active DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_interests ON profiles USING GIN(interests);
```

## Step 2: Update Sent Bottles Table

Add matching and status tracking fields:

```sql
-- Add matching fields to sent_bottles
ALTER TABLE sent_bottles ADD COLUMN IF NOT EXISTS matched_recipient_id UUID REFERENCES auth.users(id);
ALTER TABLE sent_bottles ADD COLUMN IF NOT EXISTS match_score INTEGER DEFAULT 0;
ALTER TABLE sent_bottles ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'floating' CHECK (status IN ('floating', 'matched', 'delivered', 'read'));
ALTER TABLE sent_bottles ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;
ALTER TABLE sent_bottles ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- Create index for status queries
CREATE INDEX IF NOT EXISTS idx_sent_bottles_status ON sent_bottles(sender_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sent_bottles_recipient ON sent_bottles(matched_recipient_id);
```

## Step 3: Update Received Bottles Table

Add matching score tracking:

```sql
-- Add matching fields to received_bottles
ALTER TABLE received_bottles ADD COLUMN IF NOT EXISTS match_score INTEGER DEFAULT 0;
ALTER TABLE received_bottles ADD COLUMN IF NOT EXISTS matched_at TIMESTAMPTZ DEFAULT NOW();

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_received_bottles_status ON received_bottles(receiver_id, is_read, created_at DESC);
```

## Step 4: Create User Blocks Table

Allow users to block others from sending them bottles:

```sql
-- Create user blocks table
CREATE TABLE IF NOT EXISTS user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(blocker_id, blocked_id),
  CHECK (blocker_id != blocked_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks(blocked_id);

-- RLS Policies
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own blocks"
  ON user_blocks FOR SELECT
  USING (auth.uid() = blocker_id);

CREATE POLICY "Users can create blocks"
  ON user_blocks FOR INSERT
  WITH CHECK (auth.uid() = blocker_id);

CREATE POLICY "Users can delete their own blocks"
  ON user_blocks FOR DELETE
  USING (auth.uid() = blocker_id);
```

## Step 5: Create User Preferences Table

Store user preferences for receiving bottles:

```sql
-- Create user preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Receiving preferences
  accept_from_gender VARCHAR(50) DEFAULT 'everyone', -- 'men', 'women', 'everyone'
  accept_from_age_min INTEGER DEFAULT 18,
  accept_from_age_max INTEGER DEFAULT 100,
  max_bottles_per_day INTEGER DEFAULT 5,
  
  -- Notification preferences
  notify_on_bottle_received BOOLEAN DEFAULT TRUE,
  notify_on_bottle_read BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_user_preferences_user ON user_preferences(user_id);

-- RLS Policies
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own preferences"
  ON user_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own preferences"
  ON user_preferences FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own preferences"
  ON user_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

## Step 6: Create Bottle Delivery Queue Table

Track bottles waiting to be delivered (for floating effect):

```sql
-- Create bottle delivery queue
CREATE TABLE IF NOT EXISTS bottle_delivery_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sent_bottle_id UUID NOT NULL REFERENCES sent_bottles(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Delivery timing
  scheduled_delivery_at TIMESTAMPTZ NOT NULL,
  delivered BOOLEAN DEFAULT FALSE,
  delivered_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_delivery_queue_scheduled ON bottle_delivery_queue(scheduled_delivery_at) WHERE delivered = FALSE;
CREATE INDEX IF NOT EXISTS idx_delivery_queue_recipient ON bottle_delivery_queue(recipient_id, delivered);

-- RLS Policies
ALTER TABLE bottle_delivery_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own queued bottles"
  ON bottle_delivery_queue FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);
```

## Step 7: Create Function to Update Last Active

Automatically update last_active timestamp:

```sql
-- Function to manually mark a profile as active
CREATE OR REPLACE FUNCTION mark_profile_active(p_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET last_active = NOW()
  WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Function to automatically update last_active on profile updates
CREATE OR REPLACE FUNCTION update_last_active()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_active := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger on UPDATE
CREATE TRIGGER trigger_update_last_active
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_last_active();
```

## Step 8: Create Function to Reset Daily Counters

Reset daily bottle counters at midnight:

```sql
-- Function to reset daily counters
CREATE OR REPLACE FUNCTION reset_daily_bottle_counters()
RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET 
    bottles_received_today = 0,
    bottles_sent_today = 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: This should be called by a cron job or scheduled task daily at midnight
```

## Step 9: Create Functions to Increment Bottle Counters

Functions to increment sent and received bottle counters:

```sql
-- Function to increment bottles_sent counter
CREATE OR REPLACE FUNCTION increment_bottles_sent(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET 
    bottles_sent_today = bottles_sent_today + 1,
    total_bottles_sent = total_bottles_sent + 1,
    updated_at = NOW()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment bottles_received counter
CREATE OR REPLACE FUNCTION increment_bottles_received(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET 
    bottles_received_today = bottles_received_today + 1,
    total_bottles_received = total_bottles_received + 1,
    updated_at = NOW()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Step 10: Create Matching Statistics View

Useful view for analytics:

```sql
-- Create view for matching statistics
CREATE OR REPLACE VIEW bottle_matching_stats AS
SELECT 
  p.id as user_id,
  p.full_name,
  p.total_bottles_sent,
  p.total_bottles_received,
  p.bottles_sent_today,
  p.bottles_received_today,
  COUNT(DISTINCT sb.id) FILTER (WHERE sb.status = 'floating') as bottles_floating,
  COUNT(DISTINCT sb.id) FILTER (WHERE sb.status = 'delivered') as bottles_delivered,
  COUNT(DISTINCT sb.id) FILTER (WHERE sb.status = 'read') as bottles_read,
  AVG(sb.match_score) as avg_match_score
FROM profiles p
LEFT JOIN sent_bottles sb ON p.id = sb.sender_id
GROUP BY p.id, p.full_name, p.total_bottles_sent, p.total_bottles_received, 
         p.bottles_sent_today, p.bottles_received_today;
```

## Verification Queries

After running the migration, verify with these queries:

```sql
-- Check profiles table columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name IN ('last_active', 'bottles_received_today', 'is_active', 'receive_bottles');

-- Check sent_bottles table columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'sent_bottles' 
AND column_name IN ('matched_recipient_id', 'match_score', 'status', 'delivered_at');

-- Check new tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_blocks', 'user_preferences', 'bottle_delivery_queue');

-- Check indexes
SELECT indexname 
FROM pg_indexes 
WHERE tablename IN ('profiles', 'sent_bottles', 'received_bottles', 'user_blocks');
```

## Rollback (if needed)

```sql
-- Drop new tables
DROP TABLE IF EXISTS bottle_delivery_queue CASCADE;
DROP TABLE IF EXISTS user_preferences CASCADE;
DROP TABLE IF EXISTS user_blocks CASCADE;

-- Drop view
DROP VIEW IF EXISTS bottle_matching_stats;

-- Drop functions
DROP FUNCTION IF EXISTS reset_daily_bottle_counters();
DROP FUNCTION IF EXISTS update_last_active() CASCADE;

-- Remove columns from profiles
ALTER TABLE profiles 
  DROP COLUMN IF EXISTS last_active,
  DROP COLUMN IF EXISTS bottles_received_today,
  DROP COLUMN IF EXISTS bottles_sent_today,
  DROP COLUMN IF EXISTS total_bottles_received,
  DROP COLUMN IF EXISTS total_bottles_sent,
  DROP COLUMN IF EXISTS is_active,
  DROP COLUMN IF EXISTS receive_bottles;

-- Remove columns from sent_bottles
ALTER TABLE sent_bottles
  DROP COLUMN IF EXISTS matched_recipient_id,
  DROP COLUMN IF EXISTS match_score,
  DROP COLUMN IF EXISTS status,
  DROP COLUMN IF EXISTS delivered_at,
  DROP COLUMN IF EXISTS read_at;

-- Remove columns from received_bottles
ALTER TABLE received_bottles
  DROP COLUMN IF EXISTS match_score,
  DROP COLUMN IF EXISTS matched_at;
```

## Next Steps

After running this migration:
1. Test database structure with verification queries
2. Create Dart models for new tables
3. Implement DatabaseService methods
4. Build BottleMatchingService
5. Update UI to show floating bottles
