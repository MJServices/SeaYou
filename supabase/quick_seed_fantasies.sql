-- Quick script to add demo fantasies for testing
-- Run this in your Supabase SQL editor

-- Insert 10 diverse demo fantasies with different user IDs
-- These will be visible to all premium users in Door of Desires

INSERT INTO fantasies (user_id, text, is_active, is_anonymous_submission)
SELECT 
  id as user_id,
  CASE 
    WHEN row_number() OVER (ORDER BY id) % 10 = 1 THEN 'My innermost fantasy is to be at a beach under the moonlit sky, where a whisper becomes a promise.'
    WHEN row_number() OVER (ORDER BY id) % 10 = 2 THEN 'Under the stars, hands on the piano keys, hearts racing to the rhythm of an unspoken melody.'
    WHEN row_number() OVER (ORDER BY id) % 10 = 3 THEN 'A secret note tucked in a book at a quiet café, waiting to be discovered by the right soul.'
    WHEN row_number() OVER (ORDER BY id) % 10 = 4 THEN 'Dancing in the rain without a care, feeling completely free and alive in the moment.'
    WHEN row_number() OVER (ORDER BY id) % 10 = 5 THEN 'A spontaneous road trip to nowhere, just following the sunset and seeing where it leads.'
    WHEN row_number() OVER (ORDER BY id) % 10 = 6 THEN 'Sharing a deep conversation by a fireplace, where time stands still and nothing else matters.'
    WHEN row_number() OVER (ORDER BY id) % 10 = 7 THEN 'Walking through a hidden garden at twilight, discovering beauty in every corner.'
    WHEN row_number() OVER (ORDER BY id) % 10 = 8 THEN 'A stolen glance across a crowded room that says everything words cannot express.'
    WHEN row_number() OVER (ORDER BY id) % 10 = 9 THEN 'Watching the sunrise from a mountaintop, feeling on top of the world with someone special.'
    ELSE 'A handwritten letter that arrives unexpectedly, filled with words that touch the heart.'
  END as text,
  true as is_active,
  true as is_anonymous_submission
FROM profiles
WHERE is_active = true
LIMIT 20; -- Creates 20 fantasies from first 20 users

-- Verify fantasies were created
SELECT COUNT(*) as total_fantasies FROM fantasies;
