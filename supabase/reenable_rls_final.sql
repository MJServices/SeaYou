-- Re-enable RLS and create a working policy
-- The previous policies weren't working even with WITH CHECK (true)
-- Let's try using a policy that explicitly allows inserts for authenticated users

-- First, re-enable RLS
ALTER TABLE received_bottles ENABLE ROW LEVEL SECURITY;

-- Drop all existing INSERT policies
DROP POLICY IF EXISTS "Allow authenticated users to insert received bottles" ON received_bottles;
DROP POLICY IF EXISTS "Senders can create received bottles for recipients" ON received_bottles;
DROP POLICY IF EXISTS "Users can insert received bottles" ON received_bottles;

-- Create a new policy that allows any authenticated user to insert
-- Using a simpler approach that should definitely work
CREATE POLICY "authenticated_insert_received_bottles"
ON received_bottles
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Also ensure the SELECT and UPDATE policies use 'authenticated' role
DROP POLICY IF EXISTS "Users can view their own received bottles" ON received_bottles;
CREATE POLICY "authenticated_select_own_received_bottles"
ON received_bottles
FOR SELECT
TO authenticated
USING (auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can update their own received bottles" ON received_bottles;
CREATE POLICY "authenticated_update_own_received_bottles"
ON received_bottles
FOR UPDATE
TO authenticated
USING (auth.uid() = receiver_id);

-- Verify all policies
SELECT 
  policyname,
  cmd,
  permissive,
  roles,
  with_check,
  qual as using_clause
FROM pg_policies
WHERE tablename = 'received_bottles'
ORDER BY cmd, policyname;
