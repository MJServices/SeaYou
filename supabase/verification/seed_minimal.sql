-- Minimal seed to exercise flows (safe to run in dev/staging)

DO $$
DECLARE
  u1 uuid;
  u2 uuid;
  conv uuid;
BEGIN
  -- Pick two existing users
  SELECT id INTO u1 FROM public.profiles ORDER BY created_at LIMIT 1;
  SELECT id INTO u2 FROM public.profiles ORDER BY created_at OFFSET 1 LIMIT 1;
  IF u1 IS NULL OR u2 IS NULL THEN
    RAISE NOTICE 'Need at least 2 users in profiles to seed conversations/messages';
    RETURN;
  END IF;

  -- Ensure entitlements exist
  INSERT INTO public.entitlements (user_id, tier, source)
  VALUES (u1, 'premium', 'seed') ON CONFLICT (user_id) DO NOTHING;
  INSERT INTO public.entitlements (user_id, tier, source)
  VALUES (u2, 'free', 'seed') ON CONFLICT (user_id) DO NOTHING;

  -- Seed a fantasy for u2
  INSERT INTO public.fantasies (user_id, text, is_active)
  VALUES (u2, 'Under the moonlit sky, a whisper becomes a promise.', true)
  ON CONFLICT DO NOTHING;

  -- Create a conversation
  INSERT INTO public.conversations (user_a_id, user_b_id, title)
  VALUES (u1, u2, 'Getting to know you')
  RETURNING id INTO conv;

  -- Add Q/A messages and feeling deltas
  INSERT INTO public.messages (conversation_id, sender_id, type, text, qa_group_id, is_question, feeling_delta)
  VALUES (conv, u1, 'text', 'What is your favorite book?', gen_random_uuid(), true, 0);

  INSERT INTO public.messages (conversation_id, sender_id, type, text, qa_group_id, is_answer, feeling_delta)
  VALUES (conv, u2, 'text', 'I love The Night Circus.', (SELECT qa_group_id FROM public.messages WHERE conversation_id = conv AND is_question = true ORDER BY created_at DESC LIMIT 1), true, 10);

  -- Outbox example for random matching
  INSERT INTO public.messages_outbox (sender_id, text, min_age, max_age, max_distance_km, target_gender)
  VALUES (u1, 'An anonymous hello to someone nearby.', 21, 40, 50, 'everyone');
END $$;

