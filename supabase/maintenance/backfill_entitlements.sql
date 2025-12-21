-- Backfill entitlements from profiles.tier
INSERT INTO public.entitlements (user_id, tier, source, expires_at, updated_at)
SELECT p.id, COALESCE(p.tier, 'free'), 'backfill', NULL, now()
FROM public.profiles p
ON CONFLICT (user_id) DO UPDATE SET
  tier = EXCLUDED.tier,
  source = 'backfill',
  updated_at = now();

