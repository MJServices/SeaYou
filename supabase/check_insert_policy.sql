-- Check the INSERT policy for received_bottles
SELECT 
  policyname,
  cmd as operation,
  qual as using_clause,
  with_check as check_clause
FROM pg_policies
WHERE tablename = 'received_bottles' AND cmd = 'INSERT';
