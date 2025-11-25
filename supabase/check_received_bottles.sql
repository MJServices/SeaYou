-- Check received_bottles table structure and RLS policies
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'received_bottles'
ORDER BY ordinal_position;

-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'received_bottles';

-- Check if there are any received bottles for the current user (we can't know the ID here, but we can check total count)
SELECT count(*) FROM received_bottles;
