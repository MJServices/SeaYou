-- Face verify stub: update ai_face_score and first face flag when above threshold
CREATE OR REPLACE FUNCTION public.face_verify(photo_id uuid, score int, threshold int DEFAULT 75)
RETURNS boolean AS $$
DECLARE
  p RECORD;
BEGIN
  SELECT * INTO p FROM public.profile_photos WHERE id = photo_id;
  IF NOT FOUND THEN RETURN FALSE; END IF;

  UPDATE public.profile_photos
    SET ai_face_score = score,
        is_face = TRUE,
        is_first_face_photo = COALESCE(is_first_face_photo, FALSE) OR (score >= threshold)
    WHERE id = photo_id;

  RETURN score >= threshold;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Optional: enforce max face photos per user (limit 1 first-face)
CREATE OR REPLACE FUNCTION public.enforce_face_photo_limit()
RETURNS trigger AS $$
DECLARE
  cnt int;
BEGIN
  IF NEW.is_face IS TRUE AND NEW.is_first_face_photo IS TRUE THEN
    SELECT COUNT(*) INTO cnt FROM public.profile_photos
      WHERE user_id = NEW.user_id AND is_first_face_photo IS TRUE;
    IF cnt > 0 THEN
      RAISE EXCEPTION 'FIRST_FACE_EXISTS';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_enforce_face_photo_limit ON public.profile_photos;
CREATE TRIGGER trg_enforce_face_photo_limit
BEFORE INSERT OR UPDATE ON public.profile_photos
FOR EACH ROW EXECUTE FUNCTION public.enforce_face_photo_limit();
