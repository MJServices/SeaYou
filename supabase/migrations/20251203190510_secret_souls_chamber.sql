-- Profiles tier
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS tier TEXT CHECK (tier IN ('free','premium','elite')) DEFAULT 'free';

-- Profile photos table
CREATE TABLE IF NOT EXISTS public.profile_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  url text NOT NULL,
  is_face boolean DEFAULT false,
  show_in_secret_souls boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Photos flags and validation
ALTER TABLE public.profile_photos ADD COLUMN IF NOT EXISTS is_first_face_photo boolean DEFAULT false;
ALTER TABLE public.profile_photos ADD COLUMN IF NOT EXISTS is_visible_in_secret_souls boolean DEFAULT false;
ALTER TABLE public.profile_photos ADD COLUMN IF NOT EXISTS is_hidden boolean DEFAULT false;
ALTER TABLE public.profile_photos ADD COLUMN IF NOT EXISTS ai_face_score numeric;
ALTER TABLE public.profile_photos ADD CONSTRAINT ai_face_score_bounds CHECK (ai_face_score IS NULL OR (ai_face_score >= 0 AND ai_face_score <= 100));

-- Fantasies table
CREATE TABLE IF NOT EXISTS public.fantasies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  text text NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Fantasies anonymity flag
ALTER TABLE public.fantasies ADD COLUMN IF NOT EXISTS is_anonymous_submission boolean DEFAULT true;

-- Fantasy reports
CREATE TABLE IF NOT EXISTS public.fantasy_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fantasy_id uuid NOT NULL REFERENCES public.fantasies(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason text,
  created_at timestamptz DEFAULT now()
);

-- Conversations anonymous flags
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS is_anonymous_elite boolean DEFAULT false;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS fantasy_id uuid NULL REFERENCES public.fantasies(id) ON DELETE SET NULL;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS mask_a text;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS mask_b text;

-- RLS policies (simplified stubs; refine as needed)
ALTER TABLE public.profile_photos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profile_photos_owner_rw ON public.profile_photos;
CREATE POLICY profile_photos_owner_rw ON public.profile_photos
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS profile_photos_public_read ON public.profile_photos;
CREATE POLICY profile_photos_public_read ON public.profile_photos
  FOR SELECT USING (show_in_secret_souls = true);

ALTER TABLE public.fantasies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fantasies_owner_rw ON public.fantasies;
CREATE POLICY fantasies_owner_rw ON public.fantasies
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS fantasies_public_read ON public.fantasies;
CREATE POLICY fantasies_public_read ON public.fantasies
  FOR SELECT USING (is_active = true);

ALTER TABLE public.fantasy_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fantasy_reports_owner_insert ON public.fantasy_reports;
CREATE POLICY fantasy_reports_owner_insert ON public.fantasy_reports
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);
