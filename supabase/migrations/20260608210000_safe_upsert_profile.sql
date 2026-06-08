-- ============================================================
-- FIX: "duplicate key value violates unique constraint profiles_email_key"
-- 
-- Root cause: A user re-registers with the same email. The first attempt
-- created a ghost profile row (by verify-otp stub) under auth_user_id_A.
-- The second attempt creates a new auth user (auth_user_id_B) with the same
-- email. createProfile() upsert(onConflict: 'id') tries to INSERT with id_B
-- but email is already taken by id_A -> unique constraint violation.
--
-- Fix: SECURITY DEFINER function that:
-- 1. Deletes any ghost profile with the same email but different ID
-- 2. Performs the upsert safely
-- ============================================================

CREATE OR REPLACE FUNCTION public.safe_upsert_profile(
  p_id uuid,
  p_email text,
  p_full_name text,
  p_age int,
  p_birth_year int,
  p_city text,
  p_about text,
  p_sexual_orientation text[],
  p_show_orientation boolean,
  p_expectation text,
  p_interested_in text,
  p_interests text[],
  p_avatar_url text DEFAULT NULL,
  p_language text DEFAULT NULL,
  p_secret_desire text DEFAULT NULL,
  p_secret_quote text DEFAULT NULL,
  p_secret_audio_url text DEFAULT NULL,
  p_gender text DEFAULT NULL,
  p_department text DEFAULT NULL,
  p_tier text DEFAULT 'free',
  p_is_premium boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER  -- Runs as DB owner, bypasses RLS for ghost cleanup
SET search_path = public
AS $$
BEGIN
  -- Step 1: Remove ghost profiles with the same email but a DIFFERENT user ID.
  -- These are orphaned rows from previous failed/incomplete registrations.
  DELETE FROM public.profiles
  WHERE email = p_email
    AND id != p_id;

  -- Step 2: Upsert the real profile. ON CONFLICT on id → UPDATE all fields.
  INSERT INTO public.profiles (
    id, email, full_name, age, birth_year, city, about,
    sexual_orientation, show_orientation, expectation, interested_in, interests,
    avatar_url, language, secret_desire, secret_quote, secret_audio_url,
    gender, department, tier, is_premium, is_blocked, updated_at
  ) VALUES (
    p_id, p_email, p_full_name, p_age, p_birth_year, p_city, p_about,
    p_sexual_orientation, p_show_orientation, p_expectation, p_interested_in, p_interests,
    p_avatar_url, p_language, p_secret_desire, p_secret_quote, p_secret_audio_url,
    p_gender, p_department, p_tier, p_is_premium, false, now()
  )
  ON CONFLICT (id) DO UPDATE SET
    email               = EXCLUDED.email,
    full_name           = EXCLUDED.full_name,
    age                 = EXCLUDED.age,
    birth_year          = EXCLUDED.birth_year,
    city                = EXCLUDED.city,
    about               = EXCLUDED.about,
    sexual_orientation  = EXCLUDED.sexual_orientation,
    show_orientation    = EXCLUDED.show_orientation,
    expectation         = EXCLUDED.expectation,
    interested_in       = EXCLUDED.interested_in,
    interests           = EXCLUDED.interests,
    avatar_url          = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url),
    language            = EXCLUDED.language,
    secret_desire       = EXCLUDED.secret_desire,
    secret_quote        = EXCLUDED.secret_quote,
    secret_audio_url    = EXCLUDED.secret_audio_url,
    gender              = EXCLUDED.gender,
    department          = EXCLUDED.department,
    tier                = EXCLUDED.tier,
    is_premium          = EXCLUDED.is_premium,
    updated_at          = now();
END;
$$;

-- Grant execute to authenticated users only
REVOKE ALL ON FUNCTION public.safe_upsert_profile FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.safe_upsert_profile TO authenticated;
