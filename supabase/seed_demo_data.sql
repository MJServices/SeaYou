-- ============================================
-- SeaYou App - Demo Data Seed File
-- ============================================
-- This file creates demo users and bottles for testing
-- Run this after clearing the database to get a clean test environment

-- ============================================
-- STEP 1: Clear existing data (in correct order to respect foreign keys)
-- ============================================

-- Disable RLS temporarily for data manipulation
ALTER TABLE received_bottles DISABLE ROW LEVEL SECURITY;
ALTER TABLE sent_bottles DISABLE ROW LEVEL SECURITY;
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Clear existing data
DELETE FROM received_bottles;
DELETE FROM sent_bottles;
DELETE FROM bottle_delivery_queue;
DELETE FROM profiles WHERE id NOT IN (SELECT id FROM auth.users);

-- ============================================
-- STEP 2: Create demo user profiles
-- ============================================
-- Note: These users must exist in auth.users first
-- You need to sign up these users through the app or Supabase Auth

-- Demo User 1: Alice (Dreamy, looking for friendship)
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  'c1497662-cb9d-4524-bacd-af26df277271', -- ayancoder8@gmail.com
  'ayancoder8@gmail.com',
  'Alice',
  25,
  'San Francisco',
  'Love stargazing and deep conversations 🌟',
  ARRAY['Straight'],
  true,
  'Friendship',
  'Everyone',
  ARRAY['Art', 'Music', 'Travel'],
  'English',
  true,
  true
) ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  age = EXCLUDED.age,
  city = EXCLUDED.city,
  about = EXCLUDED.about;

-- Demo User 2: Bob (Playful, looking for dating)
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  '4c4d60d5-a1f9-4d45-9d25-917fb3fae034', -- mjdev000@gmail.com
  'mjdev000@gmail.com',
  'Bob',
  28,
  'New York',
  'Adventure seeker and coffee enthusiast ☕',
  ARRAY['Straight'],
  true,
  'Dating',
  'Women',
  ARRAY['Sports', 'Food', 'Movies'],
  'English',
  true,
  true
) ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  age = EXCLUDED.age,
  city = EXCLUDED.city,
  about = EXCLUDED.about;

-- Demo User 3: Charlie (Calm, looking for friendship)
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  '7b52709a-0b3c-4665-8ae1-90147dda49b3', -- minhaj.freelancerr@gmail.com
  'minhaj.freelancerr@gmail.com',
  'Charlie',
  30,
  'Los Angeles',
  'Yoga instructor and nature lover 🧘',
  ARRAY['Straight'],
  false,
  'Friendship',
  'Everyone',
  ARRAY['Fitness', 'Nature', 'Reading'],
  'English',
  true,
  true
) ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  age = EXCLUDED.age,
  city = EXCLUDED.city,
  about = EXCLUDED.about;

-- ============================================
-- STEP 3: Create demo sent bottles
-- ============================================

-- Alice sends to Bob
INSERT INTO sent_bottles (id, sender_id, matched_recipient_id, content_type, message, mood, status, match_score, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  'c1497662-cb9d-4524-bacd-af26df277271',
  '4c4d60d5-a1f9-4d45-9d25-917fb3fae034',
  'text',
  'Hey! I found your bottle floating in the digital sea 🌊 Would love to chat about your favorite coffee spots!',
  'Curious',
  'delivered',
  85,
  NOW() - INTERVAL '2 days',
  NOW() - INTERVAL '2 days'
);

-- Bob sends to Alice
INSERT INTO sent_bottles (id, sender_id, matched_recipient_id, content_type, message, mood, status, match_score, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  '4c4d60d5-a1f9-4d45-9d25-917fb3fae034',
  'c1497662-cb9d-4524-bacd-af26df277271',
  'text',
  'Your bottle caught my eye! ✨ I love stargazing too. Ever been to Griffith Observatory?',
  'Dreamy',
  'delivered',
  90,
  NOW() - INTERVAL '1 day',
  NOW() - INTERVAL '1 day'
);

-- Charlie sends to Bob
INSERT INTO sent_bottles (id, sender_id, matched_recipient_id, content_type, message, mood, status, match_score, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  '7b52709a-0b3c-4665-8ae1-90147dda49b3',
  '4c4d60d5-a1f9-4d45-9d25-917fb3fae034',
  'text',
  'Namaste! 🙏 Your adventurous spirit resonates with me. Want to join a hiking trip?',
  'Calm',
  'delivered',
  75,
  NOW() - INTERVAL '3 hours',
  NOW() - INTERVAL '3 hours'
);

-- ============================================
-- STEP 4: Create corresponding received bottles
-- ============================================

-- Bob receives from Alice
INSERT INTO received_bottles (id, receiver_id, sender_id, content_type, message, mood, is_read, match_score, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  '4c4d60d5-a1f9-4d45-9d25-917fb3fae034',
  'c1497662-cb9d-4524-bacd-af26df277271',
  'text',
  'Hey! I found your bottle floating in the digital sea 🌊 Would love to chat about your favorite coffee spots!',
  'Curious',
  false,
  85,
  NOW() - INTERVAL '2 days',
  NOW() - INTERVAL '2 days'
);

-- Alice receives from Bob
INSERT INTO received_bottles (id, receiver_id, sender_id, content_type, message, mood, is_read, match_score, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  'c1497662-cb9d-4524-bacd-af26df277271',
  '4c4d60d5-a1f9-4d45-9d25-917fb3fae034',
  'text',
  'Your bottle caught my eye! ✨ I love stargazing too. Ever been to Griffith Observatory?',
  'Dreamy',
  true,
  90,
  NOW() - INTERVAL '1 day',
  NOW() - INTERVAL '1 day'
);

-- Bob receives from Charlie
INSERT INTO received_bottles (id, receiver_id, sender_id, content_type, message, mood, is_read, match_score, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  '4c4d60d5-a1f9-4d45-9d25-917fb3fae034',
  '7b52709a-0b3c-4665-8ae1-90147dda49b3',
  'text',
  'Namaste! 🙏 Your adventurous spirit resonates with me. Want to join a hiking trip?',
  'Calm',
  false,
  75,
  NOW() - INTERVAL '3 hours',
  NOW() - INTERVAL '3 hours'
);

-- ============================================
-- STEP 5: Update bottle counters
-- ============================================

UPDATE profiles SET 
  total_bottles_sent = 1,
  total_bottles_received = 1,
  bottles_sent_today = 0,
  bottles_received_today = 0
WHERE id = 'c1497662-cb9d-4524-bacd-af26df277271';

UPDATE profiles SET 
  total_bottles_sent = 1,
  total_bottles_received = 2,
  bottles_sent_today = 0,
  bottles_received_today = 0
WHERE id = '4c4d60d5-a1f9-4d45-9d25-917fb3fae034';

UPDATE profiles SET 
  total_bottles_sent = 1,
  total_bottles_received = 0,
  bottles_sent_today = 0,
  bottles_received_today = 0
WHERE id = '7b52709a-0b3c-4665-8ae1-90147dda49b3';

-- ============================================
-- STEP 6: Re-enable RLS with proper policies
-- ============================================

-- Re-enable RLS
ALTER TABLE received_bottles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sent_bottles ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create policies for received_bottles
DROP POLICY IF EXISTS "authenticated_insert_received_bottles" ON received_bottles;
DROP POLICY IF EXISTS "authenticated_select_own_received_bottles" ON received_bottles;
DROP POLICY IF EXISTS "authenticated_update_own_received_bottles" ON received_bottles;

CREATE POLICY "authenticated_insert_received_bottles"
ON received_bottles FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "authenticated_select_own_received_bottles"
ON received_bottles FOR SELECT
TO authenticated
USING (auth.uid() = receiver_id);

CREATE POLICY "authenticated_update_own_received_bottles"
ON received_bottles FOR UPDATE
TO authenticated
USING (auth.uid() = receiver_id);

-- ============================================
-- STEP 7: Verify the seed data
-- ============================================

SELECT 'Profiles Created:' as info, COUNT(*) as count FROM profiles
UNION ALL
SELECT 'Sent Bottles:', COUNT(*) FROM sent_bottles
UNION ALL
SELECT 'Received Bottles:', COUNT(*) FROM received_bottles;

-- Show sample data
SELECT 
  p.full_name as sender,
  r.message,
  r.mood,
  r.is_read,
  r.created_at
FROM received_bottles r
JOIN profiles p ON p.id = r.sender_id
ORDER BY r.created_at DESC
LIMIT 5;
