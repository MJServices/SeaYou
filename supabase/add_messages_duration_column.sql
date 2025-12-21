-- Add duration column to messages table if it doesn't exist
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS duration INTEGER;

-- Add is_replied column to received_bottles table if it doesn't exist
ALTER TABLE public.received_bottles 
ADD COLUMN IF NOT EXISTS is_replied BOOLEAN DEFAULT FALSE;

-- Notify that it's done
DO $$
BEGIN
    RAISE NOTICE '✅ Added duration and is_replied columns';
END $$;
