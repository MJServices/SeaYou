-- Check what users actually exist in auth.users
SELECT id, email, created_at, confirmed_at
FROM auth.users
ORDER BY created_at DESC;
