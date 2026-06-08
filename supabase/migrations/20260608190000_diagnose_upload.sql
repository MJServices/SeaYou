-- Check all storage policies for face_photos and profile_photos table
CREATE TABLE IF NOT EXISTS public.diagnostics_upload (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz DEFAULT now(),
  info jsonb
);
ALTER TABLE public.diagnostics_upload DISABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.gather_upload_diagnostics()
RETURNS jsonb AS $func$
DECLARE
  res jsonb := '{}'::jsonb;
  storage_policies jsonb;
  photo_table_info jsonb;
  profile_table_info jsonb;
BEGIN
  -- 1. Storage bucket existence and public flag
  BEGIN
    SELECT jsonb_agg(jsonb_build_object(
      'id', id,
      'name', name,
      'public', public
    )) INTO storage_policies
    FROM storage.buckets
    WHERE name IN ('face_photos', 'avatars', 'gallery_photos');
    res := jsonb_set(res, '{storage_buckets}', COALESCE(storage_policies, '[]'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    res := jsonb_set(res, '{storage_buckets_error}', to_jsonb(SQLERRM));
  END;

  -- 2. Storage policies on storage.objects for face_photos
  BEGIN
    SELECT jsonb_agg(jsonb_build_object(
      'policyname', policyname,
      'cmd', cmd,
      'qual', qual,
      'with_check', with_check
    )) INTO storage_policies
    FROM pg_policies
    WHERE tablename = 'objects' AND schemaname = 'storage';
    res := jsonb_set(res, '{storage_object_policies}', COALESCE(storage_policies, '[]'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    res := jsonb_set(res, '{storage_object_policies_error}', to_jsonb(SQLERRM));
  END;

  -- 3. profile_photos table RLS policies
  BEGIN
    SELECT jsonb_agg(jsonb_build_object(
      'policyname', policyname,
      'cmd', cmd,
      'qual', qual,
      'with_check', with_check
    )) INTO photo_table_info
    FROM pg_policies
    WHERE tablename = 'profile_photos' AND schemaname = 'public';
    res := jsonb_set(res, '{profile_photos_policies}', COALESCE(photo_table_info, '[]'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    res := jsonb_set(res, '{profile_photos_policies_error}', to_jsonb(SQLERRM));
  END;

  -- 4. profiles RLS enabled?
  BEGIN
    SELECT jsonb_build_object(
      'relname', c.relname,
      'relrowsecurity', c.relrowsecurity,
      'relforcerowsecurity', c.relforcerowsecurity
    ) INTO profile_table_info
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'profiles' AND n.nspname = 'public';
    res := jsonb_set(res, '{profiles_rls_status}', COALESCE(profile_table_info, '{}'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    res := jsonb_set(res, '{profiles_rls_error}', to_jsonb(SQLERRM));
  END;

  -- 5. Check if profiles table has any NOT NULL columns without defaults
  --    (these might fail on upsert if fields are missing)
  BEGIN
    SELECT jsonb_agg(jsonb_build_object(
      'column_name', column_name,
      'is_nullable', is_nullable,
      'column_default', column_default,
      'data_type', data_type
    )) INTO photo_table_info
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND is_nullable = 'NO'
      AND column_default IS NULL;
    res := jsonb_set(res, '{profiles_required_columns}', COALESCE(photo_table_info, '[]'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    res := jsonb_set(res, '{profiles_required_error}', to_jsonb(SQLERRM));
  END;

  RETURN res;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;

INSERT INTO public.diagnostics_upload (info) VALUES (public.gather_upload_diagnostics());
