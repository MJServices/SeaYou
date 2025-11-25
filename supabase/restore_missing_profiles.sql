-- ============================================
-- SeaYou App - Restore Profiles for Existing Users
-- ============================================
-- This script ensures that all existing Auth Users have a corresponding Profile
-- This fixes the "No account found" error during sign-in

-- Temporarily disable RLS
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- 1. Restore Profile for mjdev000@gmail.com
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  '4c4d60d5-a1f9-4d45-9d25-917fb3fae034',
  'mjdev000@gmail.com',
  'MJ',
  24,
  'Karachi',
  'Developer 👨‍💻 and music lover 🎵',
  ARRAY['Straight'],
  true,
  'Friendship',
  'Everyone',
  ARRAY['Programming', 'Music', 'Reading', 'Travel'],
  'English',
  true,
  true
) ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  full_name = EXCLUDED.full_name;

-- 2. Restore Profile for minhaj.freelancerr@gmail.com
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  '7b52709a-0b3c-4665-8ae1-90147dda49b3',
  'minhaj.freelancerr@gmail.com',
  'Minhaj',
  26,
  'Karachi',
  'Freelancer 💼 and fitness enthusiast 💪',
  ARRAY['Straight'],
  true,
  'Dating',
  'Women',
  ARRAY['Fitness', 'Business', 'Sports', 'Photography'],
  'English',
  true,
  true
) ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  full_name = EXCLUDED.full_name;

-- 3. Restore Profile for mjservices410@gmail.com
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  '7b5e7220-96d6-4244-9325-6d1336e898bc',
  'mjservices410@gmail.com',
  'MJ Services',
  28,
  'Karachi',
  'Service provider 🛠️',
  ARRAY['Straight'],
  true,
  'Friendship',
  'Everyone',
  ARRAY['Business', 'Networking'],
  'English',
  true,
  true
) ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  full_name = EXCLUDED.full_name;

-- 4. Restore Profile for ayancoder8@gmail.com
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  'c1497662-cb9d-4524-bacd-af26df277271',
  'ayancoder8@gmail.com',
  'Ayan',
  25,
  'Mumbai',
  'Tech enthusiast 💻',
  ARRAY['Straight'],
  true,
  'Dating',
  'Women',
  ARRAY['Technology', 'Gaming'],
  'English',
  true,
  true
) ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  full_name = EXCLUDED.full_name;

-- Re-enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Verify profiles exist
SELECT 'Profiles Restored:' as info, COUNT(*) as count FROM profiles;
SELECT email, full_name FROM profiles;
