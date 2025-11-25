-- Check for and delete orphaned profiles (profiles with no matching auth user)

-- 1. Show orphaned profiles before deleting
SELECT 'Orphaned Profiles (To Be Deleted):' as info, *
FROM profiles
WHERE id NOT IN (SELECT id FROM auth.users);

-- 2. Delete orphaned profiles
DELETE FROM profiles
WHERE id NOT IN (SELECT id FROM auth.users);

-- 3. Verify they are gone
SELECT 'Remaining Valid Profiles:' as info, *
FROM profiles;

-- 4. Check auth users
SELECT 'Existing Auth Users:' as info, id, email
FROM auth.users;
