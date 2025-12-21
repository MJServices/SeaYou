-- RLS for outbox and matches
ALTER TABLE public.messages_outbox ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS messages_outbox_owner_rw ON public.messages_outbox;
CREATE POLICY messages_outbox_owner_rw ON public.messages_outbox
  FOR ALL USING (auth.uid() = sender_id) WITH CHECK (auth.uid() = sender_id);

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS matches_participant_select ON public.matches;
CREATE POLICY matches_participant_select ON public.matches
  FOR SELECT USING (auth.uid() = recipient_id OR auth.uid() = (SELECT sender_id FROM public.messages_outbox WHERE id = outbox_id));

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_profiles_location ON public.profiles (lat, lng);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_time ON public.messages (conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_conversations_updated ON public.conversations (updated_at);
CREATE INDEX IF NOT EXISTS idx_fantasies_created ON public.fantasies (created_at);
CREATE INDEX IF NOT EXISTS idx_entitlements_user ON public.entitlements (user_id);
CREATE INDEX IF NOT EXISTS idx_outbox_created ON public.messages_outbox (created_at);
CREATE INDEX IF NOT EXISTS idx_matches_recipient ON public.matches (recipient_id);
CREATE INDEX IF NOT EXISTS idx_profile_photos_user ON public.profile_photos (user_id);

