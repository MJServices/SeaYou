-- Create SELECT policy for conversations
CREATE POLICY "Users can read their own conversations"
ON public.conversations
FOR SELECT
USING (
  auth.uid() = user_a_id OR auth.uid() = user_b_id
);
