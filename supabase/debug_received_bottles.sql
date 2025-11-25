-- Check if any received bottles exist and show their receiver_id
SELECT id, receiver_id, sender_id, message, created_at 
FROM received_bottles;

-- Also check the current user ID again to compare
SELECT id, email FROM auth.users ORDER BY created_at DESC LIMIT 1;
