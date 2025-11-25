-- Check ALL policies on received_bottles, not just INSERT
SELECT 
  policyname,
  cmd as operation,
  permissive,
  roles,
  qual as using_clause,
  with_check as check_clause
FROM pg_policies
WHERE tablename = 'received_bottles'
ORDER BY cmd, policyname;
