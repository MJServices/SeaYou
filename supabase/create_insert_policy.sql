-- Create INSERT policy for conversations
CREATE POLICY "Users can create conversations they participate in"
ON public.conversations
FOR INSERT
WITH CHECK (
  auth.uid() = user_a_id OR auth.uid() = user_b_id
);
