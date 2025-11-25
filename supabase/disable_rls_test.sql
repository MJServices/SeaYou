-- Temporarily disable RLS to test if that's the issue
-- WARNING: This is just for testing! We'll re-enable it after confirming.

ALTER TABLE received_bottles DISABLE ROW LEVEL SECURITY;

-- Check if RLS is disabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'received_bottles';
