-- Migration to restore naughty questions table and add necessary columns to conversations
-- 20260201_naughty_questions_restore.sql

-- 1. Ensure a clean slate for naughty_questions
DROP TABLE IF EXISTS public.naughty_questions CASCADE;

-- 2. Create naughty_questions table with all required columns
CREATE TABLE public.naughty_questions (
    id SERIAL PRIMARY KEY,
    category TEXT NOT NULL,
    label TEXT NOT NULL,
    question_text TEXT NOT NULL,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Seed the 3 specific questions
INSERT INTO public.naughty_questions (id, category, label, question_text, display_order)
VALUES 
(1, 'Sweet', 'Sweet question', 'If you could describe a "perfect atmosphere," what would it be?', 1),
(2, 'Daring', 'Daring question', 'If I whisper something in your ear, would you prefer it to be sweet... or definitely not innocent?', 2),
(3, 'Naughty', 'Naughty question', 'What can a partner do to leave you completely speechless?', 3);

-- 4. Add columns to conversations table if they don't exist
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS naughty_question_id INTEGER REFERENCES public.naughty_questions(id) ON DELETE SET NULL;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS user1_naughty_answer TEXT;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS user2_naughty_answer TEXT;

-- 5. Enable RLS for naughty_questions
ALTER TABLE public.naughty_questions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view naughty questions" ON public.naughty_questions;
CREATE POLICY "Anyone can view naughty questions" ON public.naughty_questions
    FOR SELECT USING (true);

-- 6. Comments
COMMENT ON TABLE public.naughty_questions IS 'Stores interactive questions for the 75% feeling milestone';
COMMENT ON COLUMN public.conversations.naughty_question_id IS 'ID of the naughty question picked for this conversation';
COMMENT ON COLUMN public.conversations.user1_naughty_answer IS 'Answer from user A';
COMMENT ON COLUMN public.conversations.user2_naughty_answer IS 'Answer from user B';
