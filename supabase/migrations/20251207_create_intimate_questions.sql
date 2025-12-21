-- Create intimate_questions table for storing one-time intimate question answers
CREATE TABLE IF NOT EXISTS public.intimate_questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  question_1 TEXT,
  question_2 TEXT,
  question_3 TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_intimate_questions_conversation ON public.intimate_questions(conversation_id);
CREATE INDEX IF NOT EXISTS idx_intimate_questions_user ON public.intimate_questions(user_id);

-- Add comment
COMMENT ON TABLE public.intimate_questions IS 'Stores intimate question answers (one-time only per user per conversation)';

-- Enable RLS
ALTER TABLE public.intimate_questions ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view intimate questions in their conversations
CREATE POLICY "Users can view intimate questions in their conversations"
  ON public.intimate_questions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations
      WHERE id = conversation_id
      AND (user_a_id = auth.uid() OR user_b_id = auth.uid())
    )
  );

-- RLS Policy: Users can insert their own intimate questions (one time only)
CREATE POLICY "Users can insert their own intimate questions"
  ON public.intimate_questions FOR INSERT
  WITH CHECK (user_id = auth.uid());
