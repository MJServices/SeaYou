-- Check constraints on received_bottles table
SELECT
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'received_bottles'::regclass
  AND contype = 'c'; -- 'c' means CHECK constraint
