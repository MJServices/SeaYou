-- Seed demo fantasies for all users
-- This script adds 3 demo fantasies to each user in the profiles table

DO $$
DECLARE
  user_record RECORD;
  fantasy_texts TEXT[] := ARRAY[
    'My innermost fantasy is to be at a beach under the moonlit sky, a whisper becomes a promise.',
    'Under the stars, hands on the piano keys, hearts racing to the rhythm of an unspoken melody.',
    'A secret note tucked in a book at a quiet café, waiting to be discovered by the right soul.',
    'Dancing in the rain without a care, feeling completely free and alive in the moment.',
    'A spontaneous road trip to nowhere, just following the sunset and seeing where it leads.',
    'Sharing a deep conversation by a fireplace, where time stands still and nothing else matters.',
    'Walking through a hidden garden at twilight, discovering beauty in every corner.',
    'A stolen glance across a crowded room that says everything words cannot express.',
    'Watching the sunrise from a mountaintop, feeling on top of the world with someone special.',
    'A handwritten letter that arrives unexpectedly, filled with words that touch the heart.'
  ];
  random_fantasy TEXT;
BEGIN
  -- Loop through all users in profiles table
  FOR user_record IN 
    SELECT id FROM profiles WHERE is_active = true
  LOOP
    -- Add 1-2 random fantasies for each user
    FOR i IN 1..2 LOOP
      -- Select a random fantasy text
      random_fantasy := fantasy_texts[1 + floor(random() * array_length(fantasy_texts, 1))::int];
      
      -- Insert fantasy for this user
      INSERT INTO fantasies (user_id, text, is_active, is_anonymous_submission)
      VALUES (
        user_record.id,
        random_fantasy,
        true,
        true
      )
      ON CONFLICT DO NOTHING;
    END LOOP;
  END LOOP;
  
  RAISE NOTICE 'Demo fantasies seeded successfully for all users!';
END $$;

-- Verify the fantasies were created
SELECT 
  COUNT(*) as total_fantasies,
  COUNT(DISTINCT user_id) as users_with_fantasies
FROM fantasies;

-- Show sample fantasies
SELECT 
  f.id,
  f.text,
  f.created_at,
  p.email as user_email
FROM fantasies f
JOIN profiles p ON f.user_id = p.id
ORDER BY f.created_at DESC
LIMIT 10;
