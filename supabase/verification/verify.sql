-- Data validation: profiles
SELECT 'profiles_missing_email_or_id' AS check, COUNT(*) AS violations FROM public.profiles WHERE email IS NULL OR id IS NULL;
SELECT 'profiles_invalid_tier' AS check, COUNT(*) FROM public.profiles WHERE tier NOT IN ('free','premium','elite');
SELECT 'profiles_invalid_gender' AS check, COUNT(*) FROM public.profiles WHERE gender IS NOT NULL AND gender NOT IN ('male','female','nonbinary','other');
SELECT 'profiles_invalid_birth_year' AS check, COUNT(*) FROM public.profiles WHERE birth_year IS NOT NULL AND (birth_year < 1900 OR birth_year > EXTRACT(YEAR FROM now())::int);
SELECT 'profiles_invalid_lat' AS check, COUNT(*) FROM public.profiles WHERE lat IS NOT NULL AND (lat < -90 OR lat > 90);
SELECT 'profiles_invalid_lng' AS check, COUNT(*) FROM public.profiles WHERE lng IS NOT NULL AND (lng < -180 OR lng > 180);

-- Duplicates: profiles by email
SELECT 'profiles_duplicate_email' AS check, email, COUNT(*) AS cnt FROM public.profiles GROUP BY email HAVING COUNT(*) > 1;

-- Data validation: messages_outbox
SELECT 'outbox_invalid_age_range' AS check, COUNT(*) FROM public.messages_outbox WHERE min_age > max_age OR min_age < 18;
SELECT 'outbox_invalid_target_gender' AS check, COUNT(*) FROM public.messages_outbox WHERE target_gender NOT IN ('male','female','nonbinary','everyone');

-- Duplicates: matches per outbox-recipient
SELECT 'matches_duplicate_pair' AS check, outbox_id, recipient_id, COUNT(*) AS cnt FROM public.matches GROUP BY outbox_id, recipient_id HAVING COUNT(*) > 1;

-- Photo limits exceeded
SELECT 'profile_photos_over_limit' AS check, user_id, COUNT(*) AS cnt FROM public.profile_photos GROUP BY user_id HAVING COUNT(*) > 6;

-- Orphan checks (FKs should prevent but double-check)
SELECT 'messages_orphan_conversation' AS check, COUNT(*) FROM public.messages m WHERE NOT EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = m.conversation_id);
SELECT 'matches_orphan_outbox' AS check, COUNT(*) FROM public.matches mt WHERE NOT EXISTS (SELECT 1 FROM public.messages_outbox o WHERE o.id = mt.outbox_id);

-- Secret Souls visibility consistency
SELECT 'secret_souls_hidden_visible_conflict' AS check, COUNT(*) FROM public.profile_photos WHERE is_visible_in_secret_souls = true AND is_hidden = true;

-- Performance: index existence
SELECT 'index_profiles_location' AS index, * FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_profiles_location';
SELECT 'index_messages_conversation_time' AS index, * FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_messages_conversation_time';
SELECT 'index_conversations_updated' AS index, * FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_conversations_updated';
SELECT 'index_fantasies_created' AS index, * FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_fantasies_created';
SELECT 'index_entitlements_user' AS index, * FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_entitlements_user';
SELECT 'index_outbox_created' AS index, * FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_outbox_created';
SELECT 'index_matches_recipient' AS index, * FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_matches_recipient';
SELECT 'index_profile_photos_user' AS index, * FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_profile_photos_user';

-- Performance assessment: EXPLAIN typical queries
EXPLAIN ANALYZE SELECT * FROM public.messages WHERE conversation_id = (SELECT id FROM public.conversations ORDER BY updated_at DESC LIMIT 1) ORDER BY created_at ASC LIMIT 100;
EXPLAIN ANALYZE SELECT id, url FROM public.secret_souls_gallery ORDER BY created_at DESC LIMIT 100;
EXPLAIN ANALYZE SELECT p.id FROM public.profiles p WHERE p.gender = 'female' AND public.haversine_km(p.lat, p.lng, 37.7749, -122.4194) <= 50 LIMIT 100;

-- Security: RLS enabled tables
SELECT c.relname AS table, c.relrowsecurity AS rls_enabled FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relname IN ('conversations','messages','profile_photos','fantasies','fantasy_reports','entitlements','messages_outbox','matches');

-- Security: list policies
SELECT * FROM pg_policies WHERE schemaname = 'public' AND tablename IN ('conversations','messages','profile_photos','fantasies','fantasy_reports','entitlements','messages_outbox','matches') ORDER BY tablename, policyname;

-- Backup: lightweight consistency (row counts)
SELECT 'row_counts' AS summary, (SELECT COUNT(*) FROM public.profiles) AS profiles, (SELECT COUNT(*) FROM public.conversations) AS conversations, (SELECT COUNT(*) FROM public.messages) AS messages, (SELECT COUNT(*) FROM public.profile_photos) AS profile_photos, (SELECT COUNT(*) FROM public.fantasies) AS fantasies, (SELECT COUNT(*) FROM public.entitlements) AS entitlements;

