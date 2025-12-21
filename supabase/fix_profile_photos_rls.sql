-- Enable RLS on profile_photos
ALTER TABLE public.profile_photos ENABLE ROW LEVEL SECURITY;

-- Allow users to insert their own photos
DROP POLICY IF EXISTS "Users can insert their own profile photos" ON public.profile_photos;
CREATE POLICY "Users can insert their own profile photos"
ON public.profile_photos FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Allow users to view all photos (or restrict if needed, but for now public/authenticated view is good)
DROP POLICY IF EXISTS "Users can view all profile photos" ON public.profile_photos;
CREATE POLICY "Users can view all profile photos"
ON public.profile_photos FOR SELECT
TO authenticated
USING (true);

-- Allow users to update their own photos (e.g. setting flags)
DROP POLICY IF EXISTS "Users can update their own profile photos" ON public.profile_photos;
CREATE POLICY "Users can update their own profile photos"
ON public.profile_photos FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

-- Ensure profiles table allows updates (for face_photo_url)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Allow inserting profile if it doesn't exist (e.g. during signup/onboarding nuances)
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);
