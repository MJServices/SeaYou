-- Profiles: location and demographics
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS gender text CHECK (gender IN ('male','female','nonbinary','other'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS birth_year int CHECK (birth_year BETWEEN 1900 AND EXTRACT(YEAR FROM now())::int);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS lat numeric;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS lng numeric;
ALTER TABLE public.profiles ADD CONSTRAINT lat_bounds CHECK (lat IS NULL OR (lat >= -90 AND lat <= 90));
ALTER TABLE public.profiles ADD CONSTRAINT lng_bounds CHECK (lng IS NULL OR (lng >= -180 AND lng <= 180));

-- Anonymous message outbox for matching
CREATE TABLE IF NOT EXISTS public.messages_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text text NOT NULL,
  min_age int DEFAULT 18,
  max_age int DEFAULT 100,
  max_distance_km int DEFAULT 100,
  target_gender text DEFAULT 'everyone' CHECK (target_gender IN ('male','female','nonbinary','everyone')),
  created_at timestamptz DEFAULT now()
);

-- Recipient assignments for outbox
CREATE TABLE IF NOT EXISTS public.matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outbox_id uuid NOT NULL REFERENCES public.messages_outbox(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_at timestamptz DEFAULT now(),
  delivered_at timestamptz
);

-- Haversine distance function for matching (km)
CREATE OR REPLACE FUNCTION public.haversine_km(lat1 numeric, lon1 numeric, lat2 numeric, lon2 numeric)
RETURNS numeric AS $$
DECLARE
  dlat numeric := radians(lat2 - lat1);
  dlon numeric := radians(lon2 - lon1);
  a numeric := sin(dlat/2)^2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)^2;
  c numeric := 2 * atan2(sqrt(a), sqrt(1 - a));
  earth_radius_km numeric := 6371;
BEGIN
  RETURN earth_radius_km * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Enforce max 6 photos per user
CREATE OR REPLACE FUNCTION public.fn_enforce_photo_limit() RETURNS trigger AS $$
DECLARE
  cnt int;
BEGIN
  SELECT COUNT(*) INTO cnt FROM public.profile_photos WHERE user_id = NEW.user_id;
  IF cnt >= 6 THEN
    RAISE EXCEPTION 'Photo limit reached (6) for user %', NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_photo_limit ON public.profile_photos;
CREATE TRIGGER trg_enforce_photo_limit
BEFORE INSERT ON public.profile_photos
FOR EACH ROW EXECUTE PROCEDURE public.fn_enforce_photo_limit();

-- Anonymized gallery view
CREATE OR REPLACE VIEW public.secret_souls_gallery AS
SELECT id, url, created_at
FROM public.profile_photos
WHERE is_visible_in_secret_souls = true AND is_hidden = false;

