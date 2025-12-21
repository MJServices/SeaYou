-- Create UPDATE policy for conversations
CREATE POLICY "Users can update their own conversations"
ON public.conversations
FOR UPDATE
USING (
  auth.uid() = user_a_id OR auth.uid() = user_b_id
);
