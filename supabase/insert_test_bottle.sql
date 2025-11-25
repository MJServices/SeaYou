-- Insert a fake received bottle for the current user (or a specific user)
-- You need to replace 'YOUR_USER_ID' with your actual User ID from the Authentication tab
-- OR just run this and it will try to find a user to assign it to

DO $$
DECLARE
  target_user_id UUID;
  sender_user_id UUID;
  bottle_id UUID;
BEGIN
  -- 1. Get the first user found in profiles as the target (receiver)
  SELECT id INTO target_user_id FROM profiles LIMIT 1;
  
  -- 2. Get a different user as sender (or same if only one exists, for testing)
  SELECT id INTO sender_user_id FROM profiles WHERE id != target_user_id LIMIT 1;
  
  -- If no other user, just use the same one (self-message for testing)
  IF sender_user_id IS NULL THEN
    sender_user_id := target_user_id;
  END IF;

  -- 3. Create a fake sent bottle first
  INSERT INTO sent_bottles (
    sender_id, content_type, message, mood, status, created_at, updated_at
  ) VALUES (
    sender_user_id, 'text', 'Hello from the other side! 🌊 This is a test bottle.', 'Happy', 'delivered', NOW(), NOW()
  ) RETURNING id INTO bottle_id;

  -- 4. Create the received bottle
  INSERT INTO received_bottles (
    bottle_id, receiver_id, sender_id, content_type, message, mood, 
    is_read, is_replied, match_score, created_at, updated_at
  ) VALUES (
    bottle_id, target_user_id, sender_user_id, 'text', 'Hello from the other side! 🌊 This is a test bottle.', 'Happy',
    false, false, 85, NOW(), NOW()
  );

  RAISE NOTICE 'Created received bottle for user % from user %', target_user_id, sender_user_id;
END $$;
