-- Fix the INSERT policy for received_bottles
-- The issue: When User A sends a bottle to User B, User A's session tries to insert
-- a row where receiver_id = User B. But the current policy checks auth.uid() = receiver_id,
-- which fails because auth.uid() = User A, not User B.

-- Solution: Allow INSERT if the authenticated user is the SENDER, not the receiver
DROP POLICY IF EXISTS "Users can insert received bottles" ON received_bottles;

CREATE POLICY "Senders can create received bottles for recipients"
ON received_bottles FOR INSERT
WITH CHECK (auth.uid() = sender_id);

-- Verify the new policy
SELECT policyname, cmd, with_check 
FROM pg_policies 
WHERE tablename = 'received_bottles' AND cmd = 'INSERT';
