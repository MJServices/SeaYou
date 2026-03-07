-- Update process_outbox_one to include sent_bottle_id when creating received_bottles
-- This ensures the link is established when bottles are delivered via the matching system

CREATE OR REPLACE FUNCTION public.process_outbox_one(outbox_id uuid)
RETURNS int AS $$
DECLARE
  o RECORD;
  sender RECORD;
  year int := EXTRACT(YEAR FROM now())::int;
  assigned int := 0;
  rec RECORD;
  candidates RECORD;
  v_sent_bottle_id UUID;
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

    -- Create a sent_bottle entry for tracking
    INSERT INTO public.sent_bottles(sender_id, content_type, message, status, is_delivered, has_reply, created_at, updated_at)
      VALUES (o.sender_id, 'text', o.text, 'matched', TRUE, FALSE, now(), now())
      RETURNING id INTO v_sent_bottle_id;

    -- Assign
    INSERT INTO public.matches(outbox_id, recipient_id) VALUES (o.id, rec.id) ON CONFLICT DO NOTHING;
    
    -- Create received_bottle with sent_bottle_id link
    INSERT INTO public.received_bottles(receiver_id, sender_id, content_type, message, is_read, is_replied, sent_bottle_id)
      VALUES (rec.id, o.sender_id, 'text', o.text, FALSE, FALSE, v_sent_bottle_id);
    
    assigned := assigned + 1;
    IF assigned >= 20 THEN EXIT; END IF;
  END LOOP;

  RETURN assigned;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
