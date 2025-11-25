-- Insert a received bottle for the most recent user (likely YOU)
-- Matches the provided table structure (no bottle_id)

DO $$
DECLARE
  my_user_id UUID;
  sender_user_id UUID;
BEGIN
  -- 1. Get the most recently created user (assuming this is you)
  SELECT id INTO my_user_id FROM auth.users ORDER BY created_at DESC LIMIT 1;
  
  -- 2. Find a sender (anyone who is NOT you)
  SELECT id INTO sender_user_id FROM profiles WHERE id != my_user_id LIMIT 1;
  
  -- If no other user exists, use yourself as sender (just for testing)
  IF sender_user_id IS NULL THEN
    sender_user_id := my_user_id;
  END IF;

  -- 3. Create the received bottle (WITHOUT bottle_id)
  INSERT INTO received_bottles (
    receiver_id, 
    sender_id, 
    content_type, 
    message, 
    mood, 
    is_read, 
    is_replied, 
    match_score, 
    matched_at,
    created_at, 
    updated_at
  ) VALUES (
    my_user_id, 
    sender_user_id, 
    'text', 
    'Hey! I found your bottle! 🌊 This is a test message to verify the received bottles feature.', 
    'Excited',
    false, 
    false, 
    95, 
    NOW(),
    NOW(), 
    NOW()
  );

  RAISE NOTICE 'Created received bottle for user % from user %', my_user_id, sender_user_id;
END $$;
