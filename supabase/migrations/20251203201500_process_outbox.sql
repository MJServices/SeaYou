-- Process a single outbox row
CREATE OR REPLACE FUNCTION public.process_outbox_one(outbox_id uuid)
RETURNS int AS $$
DECLARE
  o RECORD;
  sender RECORD;
  year int := EXTRACT(YEAR FROM now())::int;
  assigned int := 0;
  rec RECORD;
  candidates RECORD;
BEGIN
  SELECT * INTO o FROM public.messages_outbox WHERE id = outbox_id;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  SELECT lat, lng INTO sender FROM public.profiles WHERE id = o.sender_id;
  IF sender.lat IS NULL OR sender.lng IS NULL THEN
    RETURN 0;
  END IF;

  FOR rec IN
    SELECT id, lat, lng, birth_year, gender
    FROM public.profiles
    WHERE id <> o.sender_id
      AND receive_bottles IS TRUE
  LOOP
    IF rec.birth_year IS NULL THEN CONTINUE; END IF;
    IF (year - rec.birth_year) < COALESCE(o.min_age, 18) OR (year - rec.birth_year) > COALESCE(o.max_age, 100) THEN CONTINUE; END IF;
    IF o.target_gender IS NOT NULL AND o.target_gender <> 'everyone' AND rec.gender <> o.target_gender THEN CONTINUE; END IF;
    IF rec.lat IS NULL OR rec.lng IS NULL THEN CONTINUE; END IF;
    IF public.haversine_km(sender.lat, sender.lng, rec.lat, rec.lng) > COALESCE(o.max_distance_km, 100) THEN CONTINUE; END IF;

    -- Assign
    INSERT INTO public.matches(outbox_id, recipient_id) VALUES (o.id, rec.id) ON CONFLICT DO NOTHING;
    INSERT INTO public.received_bottles(receiver_id, sender_id, content_type, message, is_read, is_replied)
      VALUES (rec.id, o.sender_id, 'text', o.text, FALSE, FALSE);
    assigned := assigned + 1;
    IF assigned >= 20 THEN EXIT; END IF;
  END LOOP;

  RETURN assigned;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Process all outbox rows
CREATE OR REPLACE FUNCTION public.process_outbox()
RETURNS int AS $$
DECLARE
  o RECORD;
  total int := 0;
  n int := 0;
BEGIN
  FOR o IN SELECT id FROM public.messages_outbox ORDER BY created_at ASC LOOP
    n := public.process_outbox_one(o.id);
    total := total + n;
  END LOOP;
  RETURN total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

