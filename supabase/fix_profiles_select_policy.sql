-- Fix profiles RLS to allow public read access
-- This is needed for:
-- 1. Sign-in flow (checking if email exists before sending OTP)
-- 2. Viewing other users' profiles (when receiving bottles)

-- Drop the restrictive SELECT policy
DROP POLICY IF EXISTS "authenticated_select_own_profile" ON profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;

-- Create a policy that allows everyone (including unauthenticated) to read profiles
CREATE POLICY "Public profiles are viewable by everyone"
ON profiles FOR SELECT
TO public
USING (true);

-- Verify the new policy
SELECT policyname, cmd, roles, qual
FROM pg_policies
WHERE tablename = 'profiles' AND cmd = 'SELECT';
