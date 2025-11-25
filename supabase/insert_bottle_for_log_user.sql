-- Insert a test bottle specifically for the user ID found in the logs
-- User ID: 7b5e7220-96d6-4244-9325-6d1336e898bc

INSERT INTO received_bottles (
  receiver_id,
  content_type,
  message,
  mood,
  is_read,
  created_at,
  updated_at
) VALUES (
  '7b5e7220-96d6-4244-9325-6d1336e898bc', -- The ID from your logs
  'text',
  'This bottle is specifically for YOU! 🌊 We found the issue!',
  'playful',
  false,
  NOW(),
  NOW()
);

-- Also ensure this user has a profile with a name
INSERT INTO profiles (id, email, full_name)
VALUES (
  '7b5e7220-96d6-4244-9325-6d1336e898bc',
  'unknown@email.com', -- Placeholder
  'Found You'
)
ON CONFLICT (id) DO UPDATE
SET full_name = 'Found You';
