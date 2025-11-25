-- Fix sent_bottles status constraint
-- This allows the 'floating', 'matched', 'delivered', 'read' status values

-- First, drop the old constraint if it exists
ALTER TABLE sent_bottles DROP CONSTRAINT IF EXISTS sent_bottles_status_check;
ALTER TABLE sent_bottles DROP CONSTRAINT IF EXISTS check_status;

-- Add the correct constraint
ALTER TABLE sent_bottles ADD CONSTRAINT sent_bottles_status_check 
  CHECK (status IN ('pending', 'floating', 'matched', 'delivered', 'read'));

-- Update the default value to 'floating' instead of 'pending'
ALTER TABLE sent_bottles ALTER COLUMN status SET DEFAULT 'floating';

-- Verify the constraint
SELECT
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'sent_bottles'::regclass
  AND contype = 'c';
