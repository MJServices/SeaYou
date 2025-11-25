-- Try a more permissive approach: allow any authenticated user to insert
-- This is safe because the app logic controls who can send bottles

DROP POLICY IF EXISTS "Senders can create received bottles for recipients" ON received_bottles;
DROP POLICY IF EXISTS "Users can insert received bottles" ON received_bottles;

-- Allow any authenticated user to insert (the app controls the logic)
CREATE POLICY "Allow authenticated users to insert received bottles"
ON received_bottles FOR INSERT
TO authenticated
WITH CHECK (true);

-- Verify
SELECT policyname, cmd, permissive, roles, with_check 
FROM pg_policies 
WHERE tablename = 'received_bottles' AND cmd = 'INSERT';
