-- Fix Feeling Increment Trigger
-- This migration updates the trigger to increment feeling on message exchanges (different sender)
-- instead of only on Q&A pairs

CREATE OR REPLACE FUNCTION public.fn_update_conversation_on_message()
RETURNS trigger AS $$
DECLARE
  last_sender uuid;
  current_percent int;
  conv_unlock_state int;
  inc int := 5; -- Default increment 5% per exchange
  new_percent int;
  new_unlock_state int;
BEGIN
  -- Get conversation state
  SELECT last_sender_id, feeling_percent, unlock_state
  INTO last_sender, current_percent, conv_unlock_state
  FROM conversations WHERE id = NEW.conversation_id;

  -- Treat NULL as 0
  current_percent := COALESCE(current_percent, 0);
  conv_unlock_state := COALESCE(conv_unlock_state, 0);

  IF last_sender IS NULL THEN
      -- First message ever. Initialize sender, no feeling bump.
      UPDATE public.conversations
      SET last_sender_id = NEW.sender_id,
          updated_at = now()
      WHERE id = NEW.conversation_id;
      
  ELSIF NEW.sender_id <> last_sender THEN
      -- It is an exchange (Reply from different user)
      -- Use specific feeling_delta if provided, else 5
      -- Note: Default value in table is 0, so we check for 0 or NULL
      inc := COALESCE(NEW.feeling_delta, 0);
      IF inc = 0 THEN inc := 5; END IF;

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
      SET exchanges_count = COALESCE(exchanges_count, 0) + 1,
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

-- Recreate trigger to ensure it's using the updated function
DROP TRIGGER IF EXISTS trg_update_conversation_on_message ON public.messages;
CREATE TRIGGER trg_update_conversation_on_message
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE PROCEDURE public.fn_update_conversation_on_message();
