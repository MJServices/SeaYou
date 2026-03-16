-- Add DELETE policies for messages and matches to allow complete history wiping during blocking
-- These complement the policies in 20260305000000

-- 1. Allow participants of a conversation to delete messages
DROP POLICY IF EXISTS messages_participants_delete ON public.messages;
CREATE POLICY messages_participants_delete ON public.messages FOR DELETE USING (
  EXISTS(
    SELECT 1 FROM public.conversations c 
    WHERE c.id = conversation_id 
    AND (auth.uid() = c.user_a_id OR auth.uid() = c.user_b_id)
  )
);

-- 2. Allow sender or receiver to delete mutual matches
DROP POLICY IF EXISTS matches_participants_delete ON public.matches;
CREATE POLICY matches_participants_delete ON public.matches FOR DELETE USING (
  auth.uid() = recipient_id OR 
  EXISTS(
    SELECT 1 FROM public.messages_outbox mo 
    WHERE mo.id = outbox_id 
    AND auth.uid() = mo.sender_id
  )
);
