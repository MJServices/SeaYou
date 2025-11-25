-- Clean up duplicate policies and ensure INSERT works
-- We'll drop ALL existing policies and recreate them cleanly

-- Drop all policies on received_bottles
DROP POLICY IF EXISTS "Users can view their own received bottles" ON received_bottles;
DROP POLICY IF EXISTS "Users c  an update their own received bottles" ON received_bottles;
DROP POLICY IF EXISTS "Allow authenticated users to insert received bottles" ON received_bottles;
DROP POLICY IF EXISTS "authenticated_insert_received_bottles" ON received_bottles;
DROP POLICY IF EXISTS "authenticated_select_own_received_bottles" ON received_bottles;
DROP POLICY IF EXISTS "authenticated_update_own_received_bottles" ON received_bottles;
DROP POLICY IF EXISTS "Senders can create received bottles for recipients" ON received_bottles;
DROP POLICY IF EXISTS "Users can insert received bottles" ON received_bottles;

-- Create clean policies

-- 1. INSERT: Allow any authenticated user to insert (needed for sending bottles)
CREATE POLICY "authenticated_insert_received_bottles"
ON received_bottles FOR INSERT
TO authenticated
WITH CHECK (true);

-- 2. SELECT: Users can see bottles where they are the receiver OR the sender
CREATE POLICY "authenticated_select_received_bottles"
ON received_bottles FOR SELECT
TO authenticated
USING (auth.uid() = receiver_id OR auth.uid() = sender_id);

-- 3. UPDATE: Users can update bottles where they are the receiver (e.g. mark as read)
CREATE POLICY "authenticated_update_received_bottles"
ON received_bottles FOR UPDATE
TO authenticated
USING (auth.uid() = receiver_id);

-- Verify
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE tablename = 'received_bottles';
