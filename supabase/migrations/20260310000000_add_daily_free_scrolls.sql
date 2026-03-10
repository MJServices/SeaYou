-- Add daily free scrolls and refresh tracking columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS daily_free_scrolls int DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_scroll_refreshed_date timestamptz;

-- Override the use_scroll function to deduct from daily_free_scrolls first
CREATE OR REPLACE FUNCTION public.use_scroll(user_id uuid)
RETURNS boolean AS $$
DECLARE
  current_regular int;
  current_daily int;
BEGIN
  SELECT scrolls_count, daily_free_scrolls INTO current_regular, current_daily FROM public.profiles WHERE id = user_id;
  
  IF current_daily > 0 THEN
    UPDATE public.profiles SET daily_free_scrolls = daily_free_scrolls - 1 WHERE id = user_id;
    RETURN true;
  ELSIF current_regular > 0 THEN
    UPDATE public.profiles SET scrolls_count = scrolls_count - 1 WHERE id = user_id;
    RETURN true;
  ELSE
    RETURN false;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
