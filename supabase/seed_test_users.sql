-- ============================================
-- SeaYou App - Large Test User Seed File
-- ============================================
-- Creates 20 diverse test users for bottle matching testing
-- Run this to populate the database with test users

-- Temporarily disable RLS for data insertion
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Clear existing test data (optional - comment out if you want to keep existing data)
-- DELETE FROM received_bottles;
-- DELETE FROM sent_bottles;
-- DELETE FROM profiles WHERE email LIKE '%test%';

-- ============================================
-- Create 20 Test Users with Diverse Profiles
-- ============================================

-- User 1: Emma, 24, Female, Straight, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'emma.test@seayou.com',
  'Emma',
  24,
  'New York',
  'Coffee addict ☕ and bookworm 📚',
  ARRAY['Straight'],
  true,
  'Dating',
  'Men',
  ARRAY['Reading', 'Coffee', 'Movies', 'Art Galleries'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 2: Alex, 27, Male, Straight, Looking for Friendship
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'alex.test@seayou.com',
  'Alex',
  27,
  'Los Angeles',
  'Gym enthusiast 💪 and tech geek 🖥️',
  ARRAY['Straight'],
  true,
  'Friendship',
  'Everyone',
  ARRAY['Fitness', 'Gaming', 'Technology', 'Basketball'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 3: Sophia, 22, Female, Bisexual, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'sophia.test@seayou.com',
  'Sophia',
  22,
  'Miami',
  'Beach lover 🏖️ and yoga instructor 🧘',
  ARRAY['Bisexual'],
  true,
  'Dating',
  'Everyone',
  ARRAY['Yoga', 'Beach', 'Meditation', 'Healthy Eating'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 4: Jake, 29, Male, Straight, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'jake.test@seayou.com',
  'Jake',
  29,
  'Chicago',
  'Foodie 🍕 and travel enthusiast ✈️',
  ARRAY['Straight'],
  true,
  'Dating',
  'Women',
  ARRAY['Travel', 'Food', 'Photography', 'Hiking'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 5: Olivia, 26, Female, Straight, Looking for Friendship
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'olivia.test@seayou.com',
  'Olivia',
  26,
  'Seattle',
  'Artist 🎨 and music lover 🎵',
  ARRAY['Straight'],
  true,
  'Friendship',
  'Everyone',
  ARRAY['Art', 'Music', 'Concerts', 'Painting'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 6: Liam, 25, Male, Gay, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'liam.test@seayou.com',
  'Liam',
  25,
  'San Francisco',
  'Fashion designer 👔 and brunch lover 🥐',
  ARRAY['Gay'],
  true,
  'Dating',
  'Men',
  ARRAY['Fashion', 'Brunch', 'Design', 'Shopping'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 7: Ava, 23, Female, Lesbian, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'ava.test@seayou.com',
  'Ava',
  23,
  'Portland',
  'Environmental activist 🌱 and cyclist 🚴',
  ARRAY['Lesbian'],
  true,
  'Dating',
  'Women',
  ARRAY['Environment', 'Cycling', 'Sustainability', 'Hiking'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 8: Noah, 28, Male, Straight, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'noah.test@seayou.com',
  'Noah',
  28,
  'Austin',
  'Musician 🎸 and craft beer enthusiast 🍺',
  ARRAY['Straight'],
  true,
  'Dating',
  'Women',
  ARRAY['Music', 'Beer', 'Live Shows', 'Guitar'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 9: Mia, 24, Female, Straight, Looking for Friendship
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'mia.test@seayou.com',
  'Mia',
  24,
  'Boston',
  'Medical student 🩺 and runner 🏃',
  ARRAY['Straight'],
  true,
  'Friendship',
  'Everyone',
  ARRAY['Running', 'Medicine', 'Science', 'Fitness'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 10: Ethan, 26, Male, Straight, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'ethan.test@seayou.com',
  'Ethan',
  26,
  'Denver',
  'Ski instructor ⛷️ and adventure seeker 🏔️',
  ARRAY['Straight'],
  true,
  'Dating',
  'Women',
  ARRAY['Skiing', 'Mountain Climbing', 'Adventure', 'Nature'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 11: Isabella, 25, Female, Bisexual, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'isabella.test@seayou.com',
  'Isabella',
  25,
  'Las Vegas',
  'Dancer 💃 and nightlife lover 🌃',
  ARRAY['Bisexual'],
  true,
  'Dating',
  'Everyone',
  ARRAY['Dancing', 'Nightlife', 'Parties', 'Music'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 12: Mason, 30, Male, Straight, Looking for Friendship
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'mason.test@seayou.com',
  'Mason',
  30,
  'Phoenix',
  'Chef 👨‍🍳 and food blogger 📝',
  ARRAY['Straight'],
  true,
  'Friendship',
  'Everyone',
  ARRAY['Cooking', 'Food', 'Blogging', 'Wine'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 13: Charlotte, 27, Female, Straight, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'charlotte.test@seayou.com',
  'Charlotte',
  27,
  'Nashville',
  'Country music fan 🎵 and horse rider 🐴',
  ARRAY['Straight'],
  true,
  'Dating',
  'Men',
  ARRAY['Country Music', 'Horses', 'Outdoors', 'Concerts'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 14: Lucas, 24, Male, Gay, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'lucas.test@seayou.com',
  'Lucas',
  24,
  'Atlanta',
  'Graphic designer 🎨 and coffee snob ☕',
  ARRAY['Gay'],
  true,
  'Dating',
  'Men',
  ARRAY['Design', 'Coffee', 'Art', 'Photography'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 15: Amelia, 22, Female, Straight, Looking for Friendship
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'amelia.test@seayou.com',
  'Amelia',
  22,
  'San Diego',
  'Surfer 🏄 and marine biologist 🐠',
  ARRAY['Straight'],
  true,
  'Friendship',
  'Everyone',
  ARRAY['Surfing', 'Ocean', 'Marine Biology', 'Beach'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 16: James, 29, Male, Straight, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'james.test@seayou.com',
  'James',
  29,
  'Dallas',
  'Entrepreneur 💼 and sports fan 🏈',
  ARRAY['Straight'],
  true,
  'Dating',
  'Women',
  ARRAY['Business', 'Football', 'Sports', 'Networking'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 17: Harper, 26, Female, Lesbian, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'harper.test@seayou.com',
  'Harper',
  26,
  'Minneapolis',
  'Writer ✍️ and bookstore owner 📚',
  ARRAY['Lesbian'],
  true,
  'Dating',
  'Women',
  ARRAY['Writing', 'Books', 'Literature', 'Poetry'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 18: Benjamin, 25, Male, Straight, Looking for Friendship
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'benjamin.test@seayou.com',
  'Benjamin',
  25,
  'Philadelphia',
  'History teacher 📖 and board game enthusiast 🎲',
  ARRAY['Straight'],
  true,
  'Friendship',
  'Everyone',
  ARRAY['History', 'Board Games', 'Teaching', 'Museums'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 19: Evelyn, 23, Female, Bisexual, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'evelyn.test@seayou.com',
  'Evelyn',
  23,
  'Orlando',
  'Theme park enthusiast 🎢 and photographer 📷',
  ARRAY['Bisexual'],
  true,
  'Dating',
  'Everyone',
  ARRAY['Theme Parks', 'Photography', 'Adventure', 'Travel'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- User 20: Logan, 28, Male, Straight, Looking for Dating
INSERT INTO profiles (id, email, full_name, age, city, about, sexual_orientation, show_orientation, expectation, interested_in, interests, language, is_active, receive_bottles)
VALUES (
  gen_random_uuid(),
  'logan.test@seayou.com',
  'Logan',
  28,
  'Detroit',
  'Car mechanic 🔧 and vintage car collector 🚗',
  ARRAY['Straight'],
  true,
  'Dating',
  'Women',
  ARRAY['Cars', 'Mechanics', 'Vintage', 'Racing'],
  'English',
  true,
  true
) ON CONFLICT (email) DO NOTHING;

-- Re-enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Verify the data
SELECT 
  'Total Test Users Created:' as info, 
  COUNT(*) as count 
FROM profiles 
WHERE email LIKE '%test@seayou.com';

-- Show sample of created users
SELECT 
  full_name,
  age,
  city,
  expectation,
  interested_in,
  array_length(interests, 1) as interest_count
FROM profiles
WHERE email LIKE '%test@seayou.com'
ORDER BY full_name
LIMIT 10;
