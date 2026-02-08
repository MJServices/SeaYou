-- Add targeting columns to sent_bottles table
ALTER TABLE public.sent_bottles ADD COLUMN IF NOT EXISTS target_min_age int;
ALTER TABLE public.sent_bottles ADD COLUMN IF NOT EXISTS target_max_age int;
ALTER TABLE public.sent_bottles ADD COLUMN IF NOT EXISTS target_gender text[]; -- Array of strings: ['Man', 'Woman', 'Non-binary']
ALTER TABLE public.sent_bottles ADD COLUMN IF NOT EXISTS target_distance_km int;

-- Add comment
COMMENT ON COLUMN public.sent_bottles.target_gender IS 'Array of target genders: Man, Woman, Non-binary, or empty for all';
