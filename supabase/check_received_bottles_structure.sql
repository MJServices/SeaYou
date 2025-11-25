-- Check the received_bottles table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'received_bottles'
ORDER BY ordinal_position;
