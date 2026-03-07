-- Add scrolls_count to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS scrolls_count int DEFAULT 0;

-- Optional: Index for performance (though less critical for a count)
CREATE INDEX IF NOT EXISTS idx_scrolls_count ON public.profiles(scrolls_count);

-- Function to use a scroll (decrement)
CREATE OR REPLACE FUNCTION public.use_scroll(user_id uuid)
RETURNS boolean AS $$
DECLARE
  current_scrolls int;
BEGIN
  SELECT scrolls_count INTO current_scrolls FROM public.profiles WHERE id = user_id;
  
  IF current_scrolls > 0 THEN
    UPDATE public.profiles SET scrolls_count = scrolls_count - 1 WHERE id = user_id;
    RETURN true;
  ELSE
    RETURN false;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment scrolls
CREATE OR REPLACE FUNCTION public.increment_scrolls(user_id uuid, amount int)
RETURNS void AS $$
BEGIN
  UPDATE public.profiles 
  SET scrolls_count = coalesce(scrolls_count, 0) + amount 
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
