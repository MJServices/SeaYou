-- ============================================
-- SeaYou App - Update Existing Users for Testing
-- ============================================
-- This script updates your existing 3 users with diverse profiles
-- so they can match with each other when sending bottles

-- Temporarily disable RLS
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Update User 1: ayancoder8@gmail.com (c1497662-cb9d-4524-bacd-af26df277271)
UPDATE profiles
SET 
  full_name = 'Ayan',
  age = 25,
  city = 'Mumbai',
  about = 'Tech enthusiast 💻 and coffee lover ☕',
  sexual_orientation = ARRAY['Straight'],
  show_orientation = true,
  expectation = 'Dating',
  interested_in = 'Women',
  interests = ARRAY['Technology', 'Coffee', 'Gaming', 'Movies'],
  language = 'English',
  is_active = true,
  receive_bottles = true
WHERE id = 'c1497662-cb9d-4524-bacd-af26df277271';

-- Update User 2: mjdev000@gmail.com (4c4d60d5-a1f9-4d45-9d25-917fb3fae034)
UPDATE profiles
SET 
  full_name = 'MJ',
  age = 24,
  city = 'Karachi',
  about = 'Developer 👨‍💻 and music lover 🎵',
  sexual_orientation = ARRAY['Straight'],
  show_orientation = true,
  expectation = 'Friendship',
  interested_in = 'Everyone',
  interests = ARRAY['Programming', 'Music', 'Reading', 'Travel'],
  language = 'English',
  is_active = true,
  receive_bottles = true
WHERE id = '4c4d60d5-a1f9-4d45-9d25-917fb3fae034';

-- Update User 3: minhaj.freelancerr@gmail.com (7b52709a-0b3c-4665-8ae1-90147dda49b3)
UPDATE profiles
SET 
  full_name = 'Minhaj',
  age = 26,
  city = 'Karachi',
  about = 'Freelancer 💼 and fitness enthusiast 💪',
  sexual_orientation = ARRAY['Straight'],
  show_orientation = true,
  expectation = 'Dating',
  interested_in = 'Women',
  interests = ARRAY['Fitness', 'Business', 'Sports', 'Photography'],
  language = 'English',
  is_active = true,
  receive_bottles = true
WHERE id = '7b52709a-0b3c-4665-8ae1-90147dda49b3';

-- Re-enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Verify the updates
SELECT 
  full_name,
  age,
  city,
  expectation,
  interested_in,
  array_length(interests, 1) as interest_count
FROM profiles
WHERE id IN (
  'c1497662-cb9d-4524-bacd-af26df277271',
  '4c4d60d5-a1f9-4d45-9d25-917fb3fae034',
  '7b52709a-0b3c-4665-8ae1-90147dda49b3'
)
ORDER BY full_name;
