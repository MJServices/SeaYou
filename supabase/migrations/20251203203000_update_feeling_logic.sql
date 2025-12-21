-- Update feeling logic to increment only on complete Q/A pairs
CREATE OR REPLACE FUNCTION public.fn_update_conversation_on_message()
RETURNS trigger AS $$
DECLARE
  inc int := 0;
  new_percent int := 0;
  has_pair boolean := false;
BEGIN
  IF NEW.is_answer IS TRUE AND NEW.qa_group_id IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM public.messages q
      WHERE q.conversation_id = NEW.conversation_id
        AND q.qa_group_id = NEW.qa_group_id
        AND q.is_question IS TRUE
        AND q.sender_id <> NEW.sender_id
    ) INTO has_pair;

    IF has_pair THEN
      inc := GREATEST(COALESCE(NEW.feeling_delta, 0), 10);
      UPDATE public.conversations c
      SET exchanges_count = COALESCE(c.exchanges_count, 0) + 1,
          last_sender_id = NEW.sender_id,
          feeling_percent = LEAST(100, COALESCE(c.feeling_percent, 0) + inc),
          unlock_state = CASE
            WHEN LEAST(100, COALESCE(c.feeling_percent, 0) + inc) >= 100 THEN 4
            WHEN LEAST(100, COALESCE(c.feeling_percent, 0) + inc) >= 75 THEN 3
            WHEN LEAST(100, COALESCE(c.feeling_percent, 0) + inc) >= 50 THEN 2
            WHEN LEAST(100, COALESCE(c.feeling_percent, 0) + inc) >= 25 THEN 1
            ELSE 0 END,
          updated_at = now()
      WHERE c.id = NEW.conversation_id;
    ELSE
      UPDATE public.conversations c
      SET last_sender_id = NEW.sender_id,
          updated_at = now()
      WHERE c.id = NEW.conversation_id;
    END IF;
  ELSE
    UPDATE public.conversations c
    SET last_sender_id = NEW.sender_id,
        updated_at = now()
    WHERE c.id = NEW.conversation_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_conversation_on_message ON public.messages;
CREATE TRIGGER trg_update_conversation_on_message
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE PROCEDURE public.fn_update_conversation_on_message();

