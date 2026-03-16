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
  -- Get user info
  SELECT id, gender, birth_year, department, bottles_received_today, tier
  INTO u 
  FROM public.profiles 
  WHERE id = target_user_id 
    AND is_active IS TRUE 
    AND receive_bottles IS TRUE;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- Premium users might have different limits, but we'll stick to 5 for matching stability
  IF u.bottles_received_today >= user_limit THEN
    RETURN 0;
  END IF;

  target_user_age := year - u.birth_year;

  -- Find eligible pending bottles (oldest first)
  FOR b IN 
    SELECT id, sender_id, target_min_age, target_max_age, target_gender, target_departments 
    FROM public.sent_bottles 
    WHERE status = 'pending'
      AND sender_id <> target_user_id
      -- Avoid already blocked users (bidirectional)
      AND NOT EXISTS (
        SELECT 1 FROM public.user_blocks ub 
        WHERE (ub.blocker_id = target_user_id AND ub.blocked_id = sender_id)
           OR (ub.blocker_id = sender_id AND ub.blocked_id = target_user_id)
      )
    ORDER BY created_at ASC
    LIMIT 20 -- Safety limit per run
  LOOP
    -- Gender Filter (Matching Man/Woman/Non-binary to DB gender strings)
    IF b.target_gender IS NOT NULL AND array_length(b.target_gender, 1) > 0 THEN
       IF NOT (
         (u.gender IN ('male', 'man') AND 'Man' = ANY(b.target_gender)) OR
         (u.gender IN ('female', 'woman', 'femme') AND 'Woman' = ANY(b.target_gender)) OR
         (u.gender IN ('nonbinary', 'non-binary') AND 'Non-binary' = ANY(b.target_gender))
       ) THEN
         CONTINUE;
       END IF;
    END IF;

    -- Age Filter
    IF (b.target_min_age IS NOT NULL AND target_user_age < b.target_min_age) OR
       (b.target_max_age IS NOT NULL AND target_user_age > b.target_max_age) THEN
       CONTINUE;
    END IF;

    -- Department Filter
    IF b.target_departments IS NOT NULL AND array_length(b.target_departments, 1) > 0 THEN
       IF NOT (u.department = ANY(b.target_departments)) THEN
         CONTINUE;
       END IF;
    END IF;

    -- Match Found!
    UPDATE public.sent_bottles 
    SET 
      matched_recipient_id = target_user_id,
      status = 'matched',
      updated_at = now()
    WHERE id = b.id;

    -- Schedule delivery (following existing pattern in bottle_delivery_queue)
    INSERT INTO public.bottle_delivery_queue (
      sent_bottle_id,
      sender_id,
      recipient_id,
      scheduled_delivery_at,
      delivered
    ) VALUES (
      b.id,
      b.sender_id,
      target_user_id,
      now() + (random() * interval '10 minutes'), -- Realistic floating delay
      false
    );

    match_count := match_count + 1;
    
    -- Check if user reached limit
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
