-- Check policies on profiles table
SELECT 
  policyname,
  cmd,
  permissive,
  roles,
  using_clause,
  with_check
FROM pg_policies
WHERE tablename = 'profiles';
