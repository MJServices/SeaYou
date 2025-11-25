-- Check sent_bottles table structure
-- Run this to see what columns exist and identify the issue

SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'sent_bottles'
ORDER BY ordinal_position;
