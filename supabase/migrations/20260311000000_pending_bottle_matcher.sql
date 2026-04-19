-- Migration: Implement Bottle Pending Matcher
-- This adds functionality to match bottles that didn't find an immediate recipient

-- 1. Function to try matching pending bottles for a specific user
-- This acts as a "pull" mechanism when a user becomes active
CREATE OR REPLACE FUNCTION public.try_match_pending_bottles_for_user(target_user_id uuid)
RETURNS int AS $$
DECLARE
  u RECORD;
  b RECORD;
  match_count int := 0;
  year int := EXTRACT(YEAR FROM now())::int;
  target_user_age int;
  user_limit int := 5; -- Default daily limit
BEGIN
  -- 1. Get user info (RECIPIENT)
  SELECT id, gender, birth_year, department, bottles_received_today, tier, interested_in
  INTO u 
  FROM public.profiles 
  WHERE id = target_user_id 
    AND is_active IS TRUE 
    AND receive_bottles IS TRUE;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- Daily limit check
  IF u.bottles_received_today >= user_limit THEN
    RETURN 0;
  END IF;

  target_user_age := year - u.birth_year;

  -- 2. Find eligible pending bottles (oldest first)
  FOR b IN 
    SELECT 
      sb.id, 
      sb.sender_id, 
      sb.target_min_age, 
      sb.target_max_age, 
      sb.target_gender, 
      sb.target_departments,
      p.gender as sender_gender -- Fetch sender gender for reciprocal check
    FROM public.sent_bottles sb
    JOIN public.profiles p ON sb.sender_id = p.id
    WHERE sb.status IN ('pending', 'floating')
      AND sb.sender_id <> target_user_id
      -- Avoid already blocked users (bidirectional)
      AND NOT EXISTS (
        SELECT 1 FROM public.user_blocks ub 
        WHERE (ub.blocker_id = target_user_id AND ub.blocked_id = sb.sender_id)
           OR (ub.blocker_id = sb.sender_id AND ub.blocked_id = target_user_id)
      )
      -- Avoid double matching
      AND NOT EXISTS (
        SELECT 1 FROM public.bottle_delivery_queue bdq
        WHERE bdq.sent_bottle_id = sb.id AND bdq.recipient_id = target_user_id
      )
      -- ⚡ STRICT HISTORY EXCLUSION
      AND NOT EXISTS (
        SELECT 1 FROM public.received_bottles rb
        WHERE rb.sender_id = sb.sender_id 
          AND rb.receiver_id = target_user_id
      )
    ORDER BY sb.created_at ASC
    LIMIT 20 
  LOOP
    -- A. Reciprocal Interest Check (Does the recipient want to meet the sender?)
    -- We must ensure the SENDER matches the RECIPIENT'S preference
    DECLARE
      sender_gender_lower text := LOWER(b.sender_gender);
      recipient_pref text := LOWER(u.interested_in);
      reciprocal_match boolean := false;
    BEGIN
      IF recipient_pref = 'everyone' OR recipient_pref = 'all' OR sender_gender_lower IN ('nonbinary', 'non-binary') THEN
        reciprocal_match := true;
      ELSIF (recipient_pref = 'women' OR recipient_pref = 'female') AND (sender_gender_lower IN ('female', 'woman', 'femme')) THEN
        reciprocal_match := true;
      ELSIF (recipient_pref = 'men' OR recipient_pref = 'male') AND (sender_gender_lower IN ('male', 'man', 'homme')) THEN
        reciprocal_match := true;
      END IF;

      IF NOT reciprocal_match THEN
        CONTINUE;
      END IF;
    END;

    -- B. Gender Filter (Targeting)
    IF b.target_gender IS NOT NULL AND array_length(b.target_gender, 1) > 0 THEN
       IF NOT (
         (LOWER(u.gender) IN ('male', 'man', 'homme') AND 'Man' = ANY(b.target_gender)) OR
         (LOWER(u.gender) IN ('female', 'woman', 'femme') AND 'Woman' = ANY(b.target_gender)) OR
         (LOWER(u.gender) IN ('nonbinary', 'non-binary', 'nb') AND 'Non-binary' = ANY(b.target_gender)) OR
         (u.gender = ANY(b.target_gender))
       ) THEN
         CONTINUE;
       END IF;
    END IF;

    -- C. Age Filter
    IF (b.target_min_age IS NOT NULL AND target_user_age < b.target_min_age) OR
       (b.target_max_age IS NOT NULL AND target_user_age > b.target_max_age) THEN
       CONTINUE;
    END IF;

    -- D. Department Filter
    IF b.target_departments IS NOT NULL AND array_length(b.target_departments, 1) > 0 THEN
       IF NOT (u.department = ANY(b.target_departments)) THEN
         CONTINUE;
       END IF;
    END IF;

    -- Match Found!
    UPDATE public.sent_bottles 
    SET 
      matched_recipient_id = target_user_id,
      status = 'delivered', 
      delivered_at = now(),
      updated_at = now()
    WHERE id = b.id;

    INSERT INTO public.bottle_delivery_queue (
      sent_bottle_id, sender_id, recipient_id, scheduled_delivery_at, delivered, delivered_at
    ) VALUES (
      b.id, b.sender_id, target_user_id, now(), true, now()
    );

    INSERT INTO public.received_bottles (
      sent_bottle_id, receiver_id, sender_id, content_type, message, mood, audio_url, photo_url, created_at
    )
    SELECT id, target_user_id, sender_id, content_type, message, mood, audio_url, photo_url, now()
    FROM public.sent_bottles 
    WHERE id = b.id;

    UPDATE public.profiles 
    SET bottles_received_today = bottles_received_today + 1
    WHERE id = target_user_id;

    match_count := match_count + 1;
    
    IF (u.bottles_received_today + match_count) >= user_limit THEN
      EXIT;
    END IF;
  END LOOP;

  RETURN match_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger to pull pending bottles when a user becomes active
CREATE OR REPLACE FUNCTION public.on_user_active_match_bottles()
RETURNS trigger AS $$
BEGIN
  -- Run matching when last_active is updated (indicated user is online)
  IF (OLD.last_active IS NULL OR NEW.last_active <> OLD.last_active) THEN
    PERFORM public.try_match_pending_bottles_for_user(NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists for idempotency
DROP TRIGGER IF EXISTS trigger_user_active_match_bottles ON public.profiles;

CREATE TRIGGER trigger_user_active_match_bottles
  AFTER UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.on_user_active_match_bottles();

-- 3. Global function for periodic sweep (can be called by Cron)
CREATE OR REPLACE FUNCTION public.match_all_pending_bottles()
RETURNS int AS $$
DECLARE
  p RECORD;
  total_matches int := 0;
  n int;
BEGIN
  -- Loop through active users who haven't reached their daily limit
  FOR p IN 
    SELECT id FROM public.profiles 
    WHERE is_active IS TRUE 
      AND receive_bottles IS TRUE 
      AND bottles_received_today < 5
      AND last_active >= (now() - interval '7 days')
    ORDER BY last_active DESC
    LIMIT 100
  LOOP
    n := public.try_match_pending_bottles_for_user(p.id);
    total_matches := total_matches + n;
  END LOOP;
  
  RETURN total_matches;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
