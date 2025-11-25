-- Check ALL current policies on received_bottles
SELECT 
  policyname,
  cmd,
  permissive,
  roles,
  with_check
FROM pg_policies
WHERE tablename = 'received_bottles'
ORDER BY cmd, policyname;
