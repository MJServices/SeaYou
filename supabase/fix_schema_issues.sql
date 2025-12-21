-- Fix messages table columns
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS duration INTEGER;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_url TEXT;

-- Fix received_bottles table columns
ALTER TABLE public.received_bottles ADD COLUMN IF NOT EXISTS is_replied BOOLEAN DEFAULT FALSE;

-- Notify completion
DO $$
BEGIN
    RAISE NOTICE '✅ Fixed database schema: Added missing columns to messages and received_bottles';
END $$;
