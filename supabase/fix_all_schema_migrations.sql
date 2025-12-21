-- Comprehensive Schema Fix for SeaYou App
-- This script adds all columns known to be potentially missing in the user's database

-- 1. Fix messages table
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS duration INTEGER;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_url TEXT;

-- 2. Fix conversations table
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS last_message TEXT;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS last_message_time TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS feeling_percent INTEGER DEFAULT 0;

-- 3. Fix received_bottles table
ALTER TABLE public.received_bottles ADD COLUMN IF NOT EXISTS is_replied BOOLEAN DEFAULT FALSE;

-- 4. Fix sent_bottles table (just in case)
ALTER TABLE public.sent_bottles ADD COLUMN IF NOT EXISTS audio_url TEXT;
ALTER TABLE public.sent_bottles ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE public.sent_bottles ADD COLUMN IF NOT EXISTS mood TEXT;

-- Notify completion
DO $$
BEGIN
    RAISE NOTICE '✅ Fixed database schema: Added missing columns to messages, conversations, received_bottles, and sent_bottles';
END $$;
