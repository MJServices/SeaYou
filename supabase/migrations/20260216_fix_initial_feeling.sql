-- Fix Initial Feeling Increment
-- This migration updates the trigger to SKIp feeling increment on the very first exchange (opener)
-- So that feeling starts at 0% and only increases on the SECOND exchange (first real reply)

CREATE OR REPLACE FUNCTION public.fn_update_conversation_on_message()
RETURNS trigger AS $$
DECLARE
  last_sender uuid;
  current_percent int;
  conv_unlock_state int;
  current_exchanges int;
  inc int := 5; -- Default increment 5% per exchange
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
      
      -- LOGIC CHANGE: Check if this is the FIRST exchange (Opener)
      IF current_exchanges = 0 THEN
          -- First exchange (Opener): Do NOT increment feeling
          inc := 0;
      ELSE
          -- Subsequent exchanges: Increment by 5% (or delta)
          inc := COALESCE(NEW.feeling_delta, 0);
          IF inc = 0 THEN inc := 5; END IF;
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
