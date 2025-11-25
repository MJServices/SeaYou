-- Test if we can insert a received bottle manually
-- This simulates what the app does when sending a bottle
INSERT INTO received_bottles (
  receiver_id,
  sender_id,
  content_type,
  message,
  mood,
  is_read
) VALUES (
  '7b5e7220-96d6-4244-9325-6d1336e898bc', -- Your user ID
  '4c4d60d5-a1f9-4d45-9d25-917fb3fae034', -- The other user ID
  'text',
  'Testing if INSERT works from SQL editor!',
  'curious',
  false
) RETURNING id, message;
