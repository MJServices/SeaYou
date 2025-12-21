-- Backfill script to link existing received_bottles to sent_bottles
-- This creates sent_bottles for existing received_bottles that don't have them

DO $$
DECLARE
  rb RECORD;
  v_sent_bottle_id UUID;
BEGIN
  -- Loop through all received_bottles that don't have a sent_bottle_id
  FOR rb IN 
    SELECT * FROM received_bottles 
    WHERE sent_bottle_id IS NULL
  LOOP
    -- Try to find an existing sent_bottle that matches
    SELECT id INTO v_sent_bottle_id
    FROM sent_bottles
    WHERE sender_id = rb.sender_id
      AND content_type = rb.content_type
      AND COALESCE(message, '') = COALESCE(rb.message, '')
      AND ABS(EXTRACT(EPOCH FROM (created_at - rb.created_at))) < 60 -- Within 60 seconds
    LIMIT 1;
    
    -- If no matching sent_bottle found, create one
    IF v_sent_bottle_id IS NULL THEN
      INSERT INTO sent_bottles(
        sender_id, 
        content_type, 
        message, 
        audio_url,
        photo_url,
        caption,
        mood,
        status, 
        is_delivered, 
        has_reply,
        created_at,
        updated_at
      )
      VALUES (
        rb.sender_id,
        rb.content_type,
        rb.message,
        rb.audio_url,
        rb.photo_url,
        rb.caption,
        rb.mood,
        CASE WHEN rb.is_replied THEN 'read' ELSE 'matched' END,
        TRUE,
        rb.is_replied,
        rb.created_at,
        rb.updated_at
      )
      RETURNING id INTO v_sent_bottle_id;
      
      RAISE NOTICE 'Created sent_bottle % for received_bottle %', v_sent_bottle_id, rb.id;
    ELSE
      RAISE NOTICE 'Found existing sent_bottle % for received_bottle %', v_sent_bottle_id, rb.id;
    END IF;
    
    -- Update the received_bottle with the sent_bottle_id
    UPDATE received_bottles
    SET sent_bottle_id = v_sent_bottle_id
    WHERE id = rb.id;
    
  END LOOP;
  
  RAISE NOTICE 'Backfill complete!';
END $$;

-- Verify the backfill
SELECT 
    COUNT(*) as total_received_bottles,
    COUNT(sent_bottle_id) as bottles_with_link,
    COUNT(*) - COUNT(sent_bottle_id) as bottles_without_link
FROM received_bottles;
