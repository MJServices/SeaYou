-- ============================================================
-- FIX: Excessive net.http_post() calls from bottle-delivery-job
-- Root cause: cron runs every minute (* * * * *) even with no
--             deliveries pending. 43,800+ HTTP calls/month.
-- Fix: Change to every 5 minutes = 8,760 calls/month (80% reduction)
-- ============================================================

-- Step 1: Unschedule the existing every-minute job
SELECT cron.unschedule('bottle-delivery-job');

-- Step 2: Re-schedule at every 5 minutes instead
SELECT cron.schedule(
  'bottle-delivery-job',
  '*/5 * * * *',
  $$
  SELECT
    net.http_post(
      url:='https://nenugkyvcewatuddrwvf.supabase.co/functions/v1/bottle-delivery',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5lbnVna3l2Y2V3YXR1ZGRyd3ZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3NTU1MjIsImV4cCI6MjA3OTMzMTUyMn0.u_pRCCVa41zgUyeQH5rh0R0j2mSONVCxx-7rjmNl9bc"}'::jsonb
    ) as request_id;
  $$
);

-- Step 3: Verify the updated schedule
SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'bottle-delivery-job';
