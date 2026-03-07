-- Add DELETE policies to allow the `blockUser` function to completely wipe history

-- 1. Allow participants to delete their mutual conversations
DROP POLICY IF EXISTS conversations_participants_delete ON public.conversations;
CREATE POLICY conversations_participants_delete ON public.conversations FOR DELETE USING (
  auth.uid() = user_a_id OR auth.uid() = user_b_id
);

-- 2. Allow sender or receiver to delete mutual received bottles (inbox wipe)
DROP POLICY IF EXISTS received_bottles_participants_delete ON public.received_bottles;
CREATE POLICY received_bottles_participants_delete ON public.received_bottles FOR DELETE USING (
  auth.uid() = sender_id OR auth.uid() = receiver_id
);

-- 3. Allow sender or matched recipient to delete mutual sent bottles
DROP POLICY IF EXISTS sent_bottles_participants_delete ON public.sent_bottles;
CREATE POLICY sent_bottles_participants_delete ON public.sent_bottles FOR DELETE USING (
  auth.uid() = sender_id OR auth.uid() = matched_recipient_id
);
