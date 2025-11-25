-- Bottle Delivery System - Verification Queries
-- Run these in Supabase SQL Editor to verify the delivery system is working

-- ========================================
-- 1. CHECK CRON JOB STATUS
-- ========================================

-- View the scheduled cron job
SELECT * FROM cron.job 
WHERE jobname = 'bottle-delivery-job';

-- View recent cron job executions (last 10)
SELECT 
  jobid,
  runid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time,
  end_time - start_time as duration
FROM cron.job_run_details 
ORDER BY start_time DESC 
LIMIT 10;

-- ========================================
-- 2. CHECK DELIVERY QUEUE
-- ========================================

-- View all pending bottles (waiting for delivery)
SELECT 
  bdq.*,
  sb.content_type,
  sb.status as bottle_status,
  sb.created_at as bottle_created_at,
  EXTRACT(EPOCH FROM (NOW() - bdq.scheduled_delivery_at)) / 60 as minutes_overdue
FROM bottle_delivery_queue bdq
JOIN sent_bottles sb ON sb.id = bdq.sent_bottle_id
WHERE bdq.delivered = false
ORDER BY bdq.scheduled_delivery_at;

-- View recently delivered bottles (last 20)
SELECT 
  bdq.*,
  sb.content_type,
  sb.status as bottle_status,
  EXTRACT(EPOCH FROM (bdq.delivered_at - bdq.scheduled_delivery_at)) / 60 as delivery_delay_minutes
FROM bottle_delivery_queue bdq
JOIN sent_bottles sb ON sb.id = bdq.sent_bottle_id
WHERE bdq.delivered = true
ORDER BY bdq.delivered_at DESC
LIMIT 20;

-- ========================================
-- 3. CHECK BOTTLE STATUSES
-- ========================================

-- Count bottles by status
SELECT 
  status,
  COUNT(*) as count
FROM sent_bottles
GROUP BY status
ORDER BY count DESC;

-- View bottles that should have been delivered but aren't
SELECT 
  sb.id,
  sb.content_type,
  sb.status,
  sb.created_at,
  bdq.scheduled_delivery_at,
  bdq.delivered,
  EXTRACT(EPOCH FROM (NOW() - bdq.scheduled_delivery_at)) / 60 as minutes_overdue
FROM sent_bottles sb
JOIN bottle_delivery_queue bdq ON bdq.sent_bottle_id = sb.id
WHERE sb.status = 'matched'
  AND bdq.delivered = false
  AND bdq.scheduled_delivery_at < NOW()
ORDER BY bdq.scheduled_delivery_at;

-- ========================================
-- 4. DELIVERY STATISTICS
-- ========================================

-- Delivery stats for last 24 hours
SELECT 
  COUNT(*) as total_deliveries,
  AVG(EXTRACT(EPOCH FROM (delivered_at - scheduled_delivery_at))) as avg_delay_seconds,
  MIN(EXTRACT(EPOCH FROM (delivered_at - scheduled_delivery_at))) as min_delay_seconds,
  MAX(EXTRACT(EPOCH FROM (delivered_at - scheduled_delivery_at))) as max_delay_seconds
FROM bottle_delivery_queue
WHERE delivered_at > NOW() - INTERVAL '24 hours';

-- Delivery success rate
SELECT 
  COUNT(CASE WHEN delivered = true THEN 1 END) as delivered_count,
  COUNT(CASE WHEN delivered = false THEN 1 END) as pending_count,
  ROUND(
    COUNT(CASE WHEN delivered = true THEN 1 END)::numeric / 
    NULLIF(COUNT(*)::numeric, 0) * 100, 
    2
  ) as delivery_rate_percent
FROM bottle_delivery_queue;

-- ========================================
-- 5. MANUAL DELIVERY TRIGGER (if needed)
-- ========================================

-- If bottles are stuck, you can manually trigger delivery
-- This calls the same logic the cron job uses

-- First, check which bottles need delivery:
SELECT 
  id,
  sent_bottle_id,
  scheduled_delivery_at,
  EXTRACT(EPOCH FROM (NOW() - scheduled_delivery_at)) / 60 as minutes_overdue
FROM bottle_delivery_queue
WHERE delivered = false
  AND scheduled_delivery_at < NOW();

-- To manually deliver a specific bottle (replace BOTTLE_ID):
/*
BEGIN;

-- Update sent bottle status
UPDATE sent_bottles
SET 
  status = 'delivered',
  delivered_at = NOW()
WHERE id = 'BOTTLE_ID';

-- Mark queue item as delivered
UPDATE bottle_delivery_queue
SET 
  delivered = true,
  delivered_at = NOW()
WHERE sent_bottle_id = 'BOTTLE_ID';

-- Increment recipient counter
SELECT increment_bottles_received('RECIPIENT_USER_ID');

COMMIT;
*/

-- ========================================
-- 6. TROUBLESHOOTING
-- ========================================

-- Check if increment functions exist
SELECT 
  proname as function_name,
  pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname IN ('increment_bottles_sent', 'increment_bottles_received', 'mark_profile_active');

-- Check RLS policies on tables
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename IN ('sent_bottles', 'received_bottles', 'bottle_delivery_queue')
ORDER BY tablename, policyname;

-- ========================================
-- 7. RESET DAILY COUNTERS (run at midnight)
-- ========================================

-- Check current bottle counts
SELECT 
  id,
  full_name,
  bottles_sent_today,
  bottles_received_today,
  total_bottles_sent,
  total_bottles_received
FROM profiles
WHERE bottles_sent_today > 0 OR bottles_received_today > 0
ORDER BY bottles_sent_today DESC, bottles_received_today DESC;

-- Reset daily counters (should be done automatically at midnight)
-- SELECT reset_daily_bottle_counters();
