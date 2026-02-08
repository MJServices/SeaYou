-- Add secret_quote column to profiles table
-- This column stores the user's secret quote that is revealed at 25% feeling bar

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS secret_quote TEXT;

-- Add comment to document the column
COMMENT ON COLUMN profiles.secret_quote IS 'Secret quote revealed at 25% feeling bar';
