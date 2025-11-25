-- Check what's actually in the received_bottles table for the logged-in user
SELECT 
  id,
  receiver_id,
  sender_id,
  content_type,
  message,
  mood,
  is_read,
  created_at
FROM received_bottles
WHERE receiver_id = '7b5e7220-96d6-4244-9325-6d1336e898bc'
ORDER BY created_at DESC;
