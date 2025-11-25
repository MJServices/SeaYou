-- Check if there are multiple INSERT policies (one might be restrictive)
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'received_bottles' AND cmd = 'INSERT'
ORDER BY policyname;
