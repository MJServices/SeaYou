-- Check constraints on sent_bottles table
SELECT
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'sent_bottles'::regclass
  AND contype = 'c'; -- 'c' means CHECK constraint
