-- Add usage tracking columns to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bottles_sent_today int DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_bottle_sent_date timestamptz;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS messages_sent_week int DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_message_sent_week_start timestamptz;

-- Add indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_bottles_sent_today ON public.profiles(bottles_sent_today);
