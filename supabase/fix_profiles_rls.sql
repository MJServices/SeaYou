-- Fix RLS policy for profiles table to allow users to create their own profile
-- The issue: Users can't INSERT their own profile due to RLS

-- Check current policies
SELECT policyname, cmd, permissive, roles, with_check, qual
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;

-- Drop existing INSERT policies
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON profiles;

-- Create a policy that allows authenticated users to insert their own profile
CREATE POLICY "authenticated_insert_own_profile"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Also ensure SELECT and UPDATE policies exist
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
CREATE POLICY "authenticated_select_own_profile"
ON profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "authenticated_update_own_profile"
ON profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id);

-- Verify the new policies
SELECT policyname, cmd, permissive, roles, with_check, qual as using_clause
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY cmd, policyname;
