-- Test creating a conversation manually
-- Replace these UUIDs with actual user IDs from your database

INSERT INTO public.conversations (
  user_a_id,
  user_b_id,
  title,
  feeling_percent,
  exchanges_count,
  unlock_state,
  created_at,
  updated_at
)
VALUES (
  'c1497662-cb9d-4524-bacd-af26df277271',  -- Replace with your current user ID
  '7b5e7220-96d6-4244-9325-6d1336e898bc',  -- Replace with another user ID
  'Test Conversation',
  0,
  0,
  0,
  NOW(),
  NOW()
)
RETURNING id, user_a_id, user_b_id, title, created_at;
