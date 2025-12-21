-- Check if RLS is enabled on conversations table
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'conversations';
