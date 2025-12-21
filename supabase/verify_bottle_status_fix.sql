-- Verify the bottle status fix is working correctly

-- 1. Check if sent_bottle_id column exists in received_bottles
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'received_bottles' AND column_name = 'sent_bottle_id';

-- 2. Check if any received_bottles have the link established
SELECT 
    rb.id as received_bottle_id,
    rb.sent_bottle_id,
    rb.receiver_id, 
    rb.sender_id,
    rb.is_replied,
    sb.status as sent_bottle_status,
    sb.has_reply as sent_bottle_has_reply
FROM received_bottles rb
LEFT JOIN sent_bottles sb ON sb.id = rb.sent_bottle_id
LIMIT 10;

-- 3. Check sent_bottles that should show as "replied" when user responds
SELECT 
    id,
    sender_id,
    status,
    has_reply,
    is_delivered,
    created_at
FROM sent_bottles
WHERE has_reply = TRUE OR status = 'read'
LIMIT 5;
