-- ============================================================
-- PERFORMANCE FIX: Chat screen loads in 20s due to 5+ sequential DB round trips
-- 
-- Current flow (sequential, each blocked by previous):
-- 1. _loadPremiumStatus → profiles (gender,avatar) + entitlements → 2-3 queries
-- 2. _loadConversation → conversations → 1 query 
-- 3. _fetchPartnerProfile → profiles (partner) + blocked_users → 2 queries
-- 4. _loadInitialMessages → messages → 1 query
-- Total: 6-7 sequential network round trips = 15-25 seconds on mobile
--
-- Fix: Single RPC that returns everything in ONE round trip.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_chat_init_data(
  p_conversation_id uuid,
  p_current_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation record;
  v_partner_id uuid;
  v_current_profile record;
  v_partner_profile record;
  v_is_blocked boolean := false;
  v_messages jsonb;
  v_entitlement record;
  v_is_access_granted boolean := false;
  result jsonb;
BEGIN
  -- 1. Fetch conversation
  SELECT * INTO v_conversation
  FROM public.conversations
  WHERE id = p_conversation_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'conversation_not_found');
  END IF;

  -- 2. Determine partner ID
  IF v_conversation.user_a_id = p_current_user_id THEN
    v_partner_id := v_conversation.user_b_id;
  ELSE
    v_partner_id := v_conversation.user_a_id;
  END IF;

  -- 3. Fetch current user's own profile (for gender, avatar, tier)
  SELECT id, gender, avatar_url, tier, is_premium, full_name
  INTO v_current_profile
  FROM public.profiles
  WHERE id = p_current_user_id;

  -- 4. Determine access: woman always gets access, otherwise check entitlements
  IF v_current_profile.gender IN ('female', 'woman', 'femme') THEN
    v_is_access_granted := true;
  ELSE
    SELECT tier, expires_at INTO v_entitlement
    FROM public.entitlements
    WHERE user_id = p_current_user_id
    LIMIT 1;

    IF v_entitlement.tier IS NOT NULL THEN
      IF v_entitlement.expires_at IS NULL OR v_entitlement.expires_at > now() THEN
        v_is_access_granted := (v_entitlement.tier IN ('premium', 'elite'));
      END IF;
    ELSIF v_current_profile.is_premium = true OR v_current_profile.tier IN ('premium', 'elite') THEN
      v_is_access_granted := true;
    END IF;
  END IF;

  -- 5. Fetch partner profile
  SELECT id, full_name, avatar_url, last_active, is_blocked, gender
  INTO v_partner_profile
  FROM public.profiles
  WHERE id = v_partner_id;

  -- 6. Check if blocked (either direction)
  SELECT EXISTS(
    SELECT 1 FROM public.blocked_users
    WHERE (blocker_id = p_current_user_id AND blocked_id = v_partner_id)
       OR (blocker_id = v_partner_id AND blocked_id = p_current_user_id)
  ) INTO v_is_blocked;

  -- 7. Fetch last 50 messages (newest first — matches app sort order)
  SELECT jsonb_agg(m ORDER BY m.created_at DESC)
  INTO v_messages
  FROM (
    SELECT id, conversation_id, sender_id, type, text, media_url, 
           reply_to_id, created_at, updated_at, is_read,
           reaction, voice_duration_seconds, is_deleted
    FROM public.messages
    WHERE conversation_id = p_conversation_id
    ORDER BY created_at DESC
    LIMIT 50
  ) m;

  -- 8. Build and return the complete result
  result := jsonb_build_object(
    'conversation', to_jsonb(v_conversation),
    'messages', COALESCE(v_messages, '[]'::jsonb),
    'current_user', jsonb_build_object(
      'id', v_current_profile.id,
      'gender', v_current_profile.gender,
      'avatar_url', v_current_profile.avatar_url,
      'tier', v_current_profile.tier,
      'is_premium', v_current_profile.is_premium,
      'is_access_granted', v_is_access_granted
    ),
    'partner', jsonb_build_object(
      'id', v_partner_profile.id,
      'full_name', v_partner_profile.full_name,
      'avatar_url', v_partner_profile.avatar_url,
      'last_active', v_partner_profile.last_active,
      'gender', v_partner_profile.gender
    ),
    'is_blocked', v_is_blocked
  );

  RETURN result;
END;
$$;

-- Grant to authenticated users only
REVOKE ALL ON FUNCTION public.get_chat_init_data FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_chat_init_data TO authenticated;
