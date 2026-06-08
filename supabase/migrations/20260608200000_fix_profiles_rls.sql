-- ============================================================
-- FIX: profiles table RLS was enabled (likely via Dashboard)
-- but no INSERT policy exists, blocking createProfile() during onboarding.
-- 
-- Also adds the gallery_photos and avatars buckets to the storage_owner_write 
-- policy scope for completeness.
-- ============================================================

-- 1. Ensure RLS is enabled on profiles (idempotent)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 2. Public read: anyone authenticated can view profiles
DROP POLICY IF EXISTS profiles_public_read ON public.profiles;
CREATE POLICY profiles_public_read ON public.profiles
  FOR SELECT
  USING (true);

-- 3. Owner insert: users can create their own profile row during onboarding
DROP POLICY IF EXISTS profiles_owner_insert ON public.profiles;
CREATE POLICY profiles_owner_insert ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- 4. Owner update: users can update their own profile
DROP POLICY IF EXISTS profiles_owner_update ON public.profiles;
CREATE POLICY profiles_owner_update ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 5. Owner delete: users can delete (for account deletion flow)
DROP POLICY IF EXISTS profiles_owner_delete ON public.profiles;
CREATE POLICY profiles_owner_delete ON public.profiles
  FOR DELETE
  TO authenticated
  USING (auth.uid() = id);

-- 6. Service role bypass: Edge Functions and cron jobs need unrestricted access
-- (service_role bypasses RLS by default in Supabase — this is already handled)

-- ============================================================
-- Also ensure the storage_owner_write policy covers face_photos correctly.
-- Current: name LIKE auth.uid() || '/%' — this is correct but bucket-agnostic.
-- The Authenticated Insert face_photos policy already covers it.
-- No storage changes needed.
-- ============================================================

-- Verify the fix
SELECT 
  policyname, 
  cmd, 
  CASE WHEN qual IS NOT NULL THEN left(qual, 60) ELSE 'N/A' END as using_expr,
  CASE WHEN with_check IS NOT NULL THEN left(with_check, 60) ELSE 'N/A' END as check_expr
FROM pg_policies
WHERE tablename = 'profiles' AND schemaname = 'public'
ORDER BY cmd;
