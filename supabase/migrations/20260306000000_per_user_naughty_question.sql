-- Migration: Add per-user naughty question selection columns
-- Replaces the shared naughty_question_id with per-user columns so each user
-- can independently choose and lock their own question without overwriting each other.

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS user1_naughty_question_id INTEGER REFERENCES public.naughty_questions(id) ON DELETE SET NULL;

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS user2_naughty_question_id INTEGER REFERENCES public.naughty_questions(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.conversations.user1_naughty_question_id IS 'Naughty question chosen by user A (locked once set)';
COMMENT ON COLUMN public.conversations.user2_naughty_question_id IS 'Naughty question chosen by user B (locked once set)';
