-- Alternative Delivery Mechanism (No pg_net required)
-- This uses a database trigger to automatically deliver bottles

-- ========================================
-- OPTION 1: Enable pg_net (Recommended)
-- ========================================

-- Simply enable the extension
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Then your existing cron job will work!

-- ========================================
-- OPTION 2: Database Trigger (Alternative)
-- ========================================

-- If pg_net is not available, use this trigger-based approach
-- This will deliver bottles immediately when they're ready

CREATE OR REPLACE FUNCTION auto_deliver_bottles()
RETURNS trigger AS $$
DECLARE
  v_bottle_id UUID;
  v_recipient_id UUID;
BEGIN
  -- Only process if bottle is ready for delivery
  IF NEW.delivered = false AND NEW.scheduled_delivery_at <= NOW() THEN
    
    v_bottle_id := NEW.sent_bottle_id;
    v_recipient_id := NEW.recipient_id;
    
    -- Update sent bottle status
    UPDATE sent_bottles
    SET 
      status = 'delivered',
      delivered_at = NOW()
    WHERE id = v_bottle_id;
    
    -- Mark queue item as delivered
    UPDATE bottle_delivery_queue
    SET 
      delivered = true,
      delivered_at = NOW()
    WHERE id = NEW.id;
    
    -- Increment recipient counter
    PERFORM increment_bottles_received(v_recipient_id);
    
    RAISE NOTICE 'Bottle % delivered to %', v_bottle_id, v_recipient_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger that checks every time a row is inserted or updated
CREATE TRIGGER trigger_auto_deliver_bottles
  AFTER INSERT OR UPDATE ON bottle_delivery_queue
  FOR EACH ROW
  EXECUTE FUNCTION auto_deliver_bottles();

-- ========================================
-- OPTION 3: Manual Delivery Function
-- ========================================

-- Create a function you can call manually or from the app
CREATE OR REPLACE FUNCTION deliver_pending_bottles()
RETURNS TABLE(
  delivered_count INT,
  error_count INT
) AS $$
DECLARE
  v_delivered INT := 0;
  v_errors INT := 0;
  v_queue_item RECORD;
BEGIN
  -- Get all bottles ready for delivery
  FOR v_queue_item IN 
    SELECT * FROM bottle_delivery_queue
    WHERE delivered = false
    AND scheduled_delivery_at <= NOW()
  LOOP
    BEGIN
      -- Update sent bottle
      UPDATE sent_bottles
      SET 
        status = 'delivered',
        delivered_at = NOW()
      WHERE id = v_queue_item.sent_bottle_id;
      
      -- Mark as delivered
      UPDATE bottle_delivery_queue
      SET 
        delivered = true,
        delivered_at = NOW()
      WHERE id = v_queue_item.id;
      
      -- Increment counter
      PERFORM increment_bottles_received(v_queue_item.recipient_id);
      
      v_delivered := v_delivered + 1;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      RAISE NOTICE 'Error delivering bottle %: %', v_queue_item.sent_bottle_id, SQLERRM;
    END;
  END LOOP;
  
  RETURN QUERY SELECT v_delivered, v_errors;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- TESTING
-- ========================================

-- Test the manual delivery function
SELECT * FROM deliver_pending_bottles();

-- ========================================
-- RECOMMENDED APPROACH
-- ========================================

-- 1. Enable pg_net extension (easiest)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. If pg_net not available, use Option 2 (trigger)
-- The trigger will deliver bottles automatically when scheduled_delivery_at passes

-- 3. For immediate testing, use Option 3 (manual function)
-- Call deliver_pending_bottles() whenever you want to deliver bottles
