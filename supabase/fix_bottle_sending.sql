-- Fix Bottle Sending - Create Missing Database Functions
-- Run this in Supabase SQL Editor to fix the "Failed to send bottle" error

-- ========================================
-- 1. CREATE MISSING FUNCTIONS
-- ========================================

-- Function to increment bottles_sent counter
CREATE OR REPLACE FUNCTION increment_bottles_sent(user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET 
    bottles_sent_today = COALESCE(bottles_sent_today, 0) + 1,
    total_bottles_sent = COALESCE(total_bottles_sent, 0) + 1,
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
    bottles_received_today = COALESCE(bottles_received_today, 0) + 1,
    total_bottles_received = COALESCE(total_bottles_received, 0) + 1,
    updated_at = NOW()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to manually mark a profile as active
CREATE OR REPLACE FUNCTION mark_profile_active(p_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET last_active = NOW()
  WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 2. VERIFY COLUMNS EXIST
-- ========================================

-- Add missing columns if they don't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_active TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bottles_received_today INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bottles_sent_today INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_bottles_received INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_bottles_sent INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS receive_bottles BOOLEAN DEFAULT TRUE;

-- Add missing columns to sent_bottles if they don't exist
ALTER TABLE sent_bottles ADD COLUMN IF NOT EXISTS matched_recipient_id UUID REFERENCES auth.users(id);
ALTER TABLE sent_bottles ADD COLUMN IF NOT EXISTS match_score INTEGER DEFAULT 0;
ALTER TABLE sent_bottles ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'floating';
ALTER TABLE sent_bottles ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

-- Add missing columns to received_bottles if they don't exist
ALTER TABLE received_bottles ADD COLUMN IF NOT EXISTS match_score INTEGER DEFAULT 0;
ALTER TABLE received_bottles ADD COLUMN IF NOT EXISTS matched_at TIMESTAMPTZ DEFAULT NOW();

-- ========================================
-- 3. CREATE BOTTLE DELIVERY QUEUE TABLE
-- ========================================

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

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own queued bottles" ON bottle_delivery_queue;

CREATE POLICY "Users can view their own queued bottles"
  ON bottle_delivery_queue FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- ========================================
-- 4. CREATE USER BLOCKS TABLE
-- ========================================

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

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own blocks" ON user_blocks;
DROP POLICY IF EXISTS "Users can create blocks" ON user_blocks;
DROP POLICY IF EXISTS "Users can delete their own blocks" ON user_blocks;

CREATE POLICY "Users can view their own blocks"
  ON user_blocks FOR SELECT
  USING (auth.uid() = blocker_id);

CREATE POLICY "Users can create blocks"
  ON user_blocks FOR INSERT
  WITH CHECK (auth.uid() = blocker_id);

CREATE POLICY "Users can delete their own blocks"
  ON user_blocks FOR DELETE
  USING (auth.uid() = blocker_id);

-- ========================================
-- 5. VERIFICATION
-- ========================================

-- Check if functions were created successfully
SELECT 
  proname as function_name,
  'Created successfully' as status
FROM pg_proc
WHERE proname IN ('increment_bottles_sent', 'increment_bottles_received', 'mark_profile_active');

-- Check if tables exist
SELECT 
  table_name,
  'Exists' as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('bottle_delivery_queue', 'user_blocks');

-- Check if columns exist in profiles
SELECT 
  column_name,
  data_type,
  'Exists' as status
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name IN ('last_active', 'bottles_received_today', 'bottles_sent_today', 'total_bottles_received', 'total_bottles_sent', 'is_active', 'receive_bottles');
