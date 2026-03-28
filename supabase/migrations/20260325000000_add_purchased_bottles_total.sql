-- Add purchased_bottles_total to profiles to track lifetime purchases
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS purchased_bottles_total int DEFAULT 0;

-- Update the increment_scrolls function to record both current and lifetime totals
CREATE OR REPLACE FUNCTION public.increment_scrolls(user_id uuid, amount int)
RETURNS void AS $$
BEGIN
  UPDATE public.profiles 
  SET 
    scrolls_count = coalesce(scrolls_count, 0) + amount,
    purchased_bottles_total = coalesce(purchased_bottles_total, 0) + amount
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
