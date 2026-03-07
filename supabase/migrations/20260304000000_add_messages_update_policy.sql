-- Add UPDATE policy for messages to allow marking as read
-- Users can only update messages in conversations they are a part of.
-- Usually, they only need to update `is_read` for messages sent by the OTHER person.

DROP POLICY IF EXISTS messages_participants_update ON public.messages;
CREATE POLICY messages_participants_update ON public.messages FOR UPDATE USING (
  EXISTS(
    SELECT 1 FROM public.conversations c 
    WHERE c.id = conversation_id 
    AND (auth.uid() = c.user_a_id OR auth.uid() = c.user_b_id)
  )
) WITH CHECK (
  EXISTS(
    SELECT 1 FROM public.conversations c 
    WHERE c.id = conversation_id 
    AND (auth.uid() = c.user_a_id OR auth.uid() = c.user_b_id)
  )
);
