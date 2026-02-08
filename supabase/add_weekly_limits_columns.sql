-- Add columns for weekly message limit tracking
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS messages_sent_week INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_message_sent_week_start TIMESTAMP WITH TIME ZONE;

-- Notify completion
DO $$
BEGIN
    RAISE NOTICE '✅ Added weekly limit columns to profiles table';
END $$;
