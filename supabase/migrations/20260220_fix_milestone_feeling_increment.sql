-- Fix Milestone Feeling Increment
-- This migration ensures that milestone messages (mood starting with 'milestone_')
-- do not increase the feeling bar, and that an explicit feeling_delta of 0 is respected.

-- 1. Change default of feeling_delta to NULL so we can distinguish "not provided" from "explicit 0"
ALTER TABLE public.messages ALTER COLUMN feeling_delta DROP DEFAULT;
ALTER TABLE public.messages ALTER COLUMN feeling_delta SET DEFAULT NULL;

-- 2. Update the trigger function
CREATE OR REPLACE FUNCTION public.fn_update_conversation_on_message()
RETURNS trigger AS $$
DECLARE
  last_sender uuid;
  current_percent int;
  conv_unlock_state int;
  current_exchanges int;
  inc int;
  new_percent int;
  new_unlock_state int;
BEGIN
  -- Get conversation state including exchanges_count
  SELECT last_sender_id, feeling_percent, unlock_state, exchanges_count
  INTO last_sender, current_percent, conv_unlock_state, current_exchanges
  FROM conversations WHERE id = NEW.conversation_id;

  -- Treat NULL as 0
  current_percent := COALESCE(current_percent, 0);
  conv_unlock_state := COALESCE(conv_unlock_state, 0);
  current_exchanges := COALESCE(current_exchanges, 0);

  IF last_sender IS NULL THEN
      -- First message ever (Bottle creation implicitly). Initialize sender, no feeling bump.
      UPDATE public.conversations
      SET last_sender_id = NEW.sender_id,
          updated_at = now()
      WHERE id = NEW.conversation_id;
      
  ELSIF NEW.sender_id <> last_sender THEN
      -- It is an exchange (Reply from different user)
      
      -- Priority 1: Milestone messages are ALWAYS neutral
      IF NEW.mood IS NOT NULL AND NEW.mood LIKE 'milestone_%' THEN
          inc := 0;
          
      -- Priority 2: Check if this is the FIRST exchange (Opener)
      ELSIF current_exchanges = 0 THEN
          -- First exchange (Opener): Do NOT increment feeling
          inc := 0;
          
      ELSE
          -- Subsequent exchanges: Increment by delta or default 5
          -- Since we changed default to NULL, COALESCE(NEW.feeling_delta, 5) 
          -- will use 5 if not provided, but respect 0 if explicitly sent.
          inc := COALESCE(NEW.feeling_delta, 5);
      END IF;

      new_percent := LEAST(100, current_percent + inc);
      
      -- Calculate new unlock state
      IF new_percent >= 100 THEN new_unlock_state := 4;
      ELSIF new_percent >= 75 THEN new_unlock_state := 3;
      ELSIF new_percent >= 50 THEN new_unlock_state := 2;
      ELSIF new_percent >= 25 THEN new_unlock_state := 1;
      ELSE new_unlock_state := 0;
      END IF;

      -- Update conversation
      UPDATE public.conversations
      SET exchanges_count = current_exchanges + 1,
          last_sender_id = NEW.sender_id,
          feeling_percent = new_percent,
          unlock_state = GREATEST(conv_unlock_state, new_unlock_state), -- Never downgrade state
          updated_at = now()
      WHERE id = NEW.conversation_id;
  ELSE
      -- Same sender sending again. Just update timestamp.
      UPDATE public.conversations
      SET last_sender_id = NEW.sender_id, -- Keep same
          updated_at = now()
      WHERE id = NEW.conversation_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
