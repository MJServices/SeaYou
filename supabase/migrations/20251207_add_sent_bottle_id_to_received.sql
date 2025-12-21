-- Add sent_bottle_id foreign key to received_bottles table
-- This links received bottles back to their original sent bottles

-- Step 1: Add the column (nullable for existing data)
ALTER TABLE public.received_bottles 
ADD COLUMN IF NOT EXISTS sent_bottle_id UUID REFERENCES public.sent_bottles(id) ON DELETE SET NULL;

-- Step 2: Create index for performance
CREATE INDEX IF NOT EXISTS idx_received_bottles_sent_bottle_id 
ON public.received_bottles(sent_bottle_id);

-- Step 3: Add comment for documentation
COMMENT ON COLUMN public.received_bottles.sent_bottle_id IS 
'Foreign key to the original sent_bottle that was delivered to this recipient';
