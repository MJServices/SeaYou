-- Verify all three policies now exist
SELECT 
  policyname,
  cmd
FROM pg_policies 
WHERE tablename = 'conversations'
ORDER BY cmd;
