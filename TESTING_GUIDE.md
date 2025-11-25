# Quick Testing Guide - Bottle Matching System

## ✅ System Status Check

Run these queries in Supabase SQL Editor to verify everything is working:

### 1. Check Cron Job is Running

```sql
-- Should show 1 row with your cron job
SELECT * FROM cron.job WHERE jobname = 'bottle-delivery-job';

-- Should show recent executions every minute
SELECT 
  start_time,
  status,
  return_message
FROM cron.job_run_details 
ORDER BY start_time DESC 
LIMIT 5;
```

**Expected**: You should see executions every minute with status 'succeeded'

### 2. Test the Full Flow

**Step 1: Send a Bottle**
1. Open the app
2. Click "Send Bottle" button
3. Create a text bottle
4. Click Preview → Send
5. Bottle should appear in "Sent Bottles" with 🌊 Floating badge

**Step 2: Verify Matching**

```sql
-- Check the bottle was created and matched
SELECT 
  id,
  content_type,
  status,
  matched_recipient_id,
  match_score,
  created_at
FROM sent_bottles
ORDER BY created_at DESC
LIMIT 1;
```

**Expected**: 
- `status` = 'matched'
- `matched_recipient_id` = some user ID
- `match_score` > 0

**Step 3: Check Delivery Queue**

```sql
-- Check bottle is in delivery queue
SELECT 
  sent_bottle_id,
  scheduled_delivery_at,
  delivered,
  EXTRACT(EPOCH FROM (scheduled_delivery_at - NOW())) / 60 as minutes_until_delivery
FROM bottle_delivery_queue
WHERE delivered = false
ORDER BY scheduled_delivery_at DESC
LIMIT 5;
```

**Expected**: 
- Your bottle should be listed
- `minutes_until_delivery` should be between 1-5 minutes (negative means ready for delivery)

**Step 4: Wait for Delivery**

Wait 1-5 minutes, then check:

```sql
-- Check if bottle was delivered
SELECT 
  sb.id,
  sb.status,
  sb.delivered_at,
  bdq.delivered,
  bdq.delivered_at as queue_delivered_at
FROM sent_bottles sb
JOIN bottle_delivery_queue bdq ON bdq.sent_bottle_id = sb.id
ORDER BY sb.created_at DESC
LIMIT 1;
```

**Expected**:
- `sb.status` = 'delivered'
- `sb.delivered_at` = timestamp
- `bdq.delivered` = true

**Step 5: Verify Recipient Received**

```sql
-- Check recipient's received bottles
SELECT 
  id,
  receiver_id,
  sender_id,
  content_type,
  match_score,
  matched_at,
  created_at
FROM received_bottles
ORDER BY created_at DESC
LIMIT 1;
```

**Expected**: Bottle should appear in recipient's received bottles

### 3. Test Settings Screen

1. Navigate to Settings (from Profile tab)
2. Change preferences:
   - Accept from: Women only
   - Age range: 25-35
   - Max bottles: 3
3. Click "Save Preferences"
4. Verify in database:

```sql
SELECT 
  user_id,
  accept_from_gender,
  accept_from_age_min,
  accept_from_age_max,
  max_bottles_per_day
FROM user_preferences
WHERE user_id = 'YOUR_USER_ID';
```

### 4. Test Blocking

**Block a User:**
```sql
-- Manually block a user for testing
INSERT INTO user_blocks (blocker_id, blocked_id, created_at)
VALUES ('YOUR_USER_ID', 'USER_TO_BLOCK_ID', NOW());
```

**Verify in App:**
1. Go to Settings → Blocked Users
2. Should see the blocked user
3. Click "Unblock"
4. User should disappear from list

**Verify Matching Respects Blocks:**
```sql
-- Send a bottle and verify it doesn't match with blocked user
-- Check the matched_recipient_id is NOT the blocked user
```

---

## 🐛 Common Issues & Fixes

### Issue: Bottles Stay "Floating" Forever

**Diagnosis:**
```sql
-- Check if cron job is running
SELECT * FROM cron.job_run_details 
WHERE jobname = 'bottle-delivery-job'
ORDER BY start_time DESC LIMIT 1;
```

**Fix:**
- If no recent runs: Cron job not set up correctly
- If runs show errors: Check Edge Function logs
- Manual delivery:

```sql
-- Manually deliver stuck bottles
UPDATE sent_bottles
SET status = 'delivered', delivered_at = NOW()
WHERE status = 'matched' 
  AND id IN (
    SELECT sent_bottle_id FROM bottle_delivery_queue 
    WHERE delivered = false 
    AND scheduled_delivery_at < NOW()
  );

UPDATE bottle_delivery_queue
SET delivered = true, delivered_at = NOW()
WHERE delivered = false 
AND scheduled_delivery_at < NOW();
```

### Issue: No Matches Found

**Diagnosis:**
```sql
-- Check how many active users exist
SELECT COUNT(*) FROM profiles WHERE is_active = true AND receive_bottles = true;

-- Check your profile preferences
SELECT * FROM profiles WHERE id = 'YOUR_USER_ID';
```

**Fix:**
- Need at least 2 users with compatible preferences
- Check gender preferences match
- Ensure users are active (last_active within 7 days)

### Issue: Settings Not Saving

**Check:**
```sql
-- Verify user_preferences table exists
SELECT * FROM user_preferences WHERE user_id = 'YOUR_USER_ID';
```

**Fix:**
- If no row: Preferences will be created on first save
- Check app console for errors

---

## 📊 Monitoring Dashboard

Run these queries to monitor system health:

```sql
-- Overall system stats
SELECT 
  (SELECT COUNT(*) FROM profiles WHERE is_active = true) as active_users,
  (SELECT COUNT(*) FROM sent_bottles WHERE created_at > NOW() - INTERVAL '24 hours') as bottles_sent_24h,
  (SELECT COUNT(*) FROM bottle_delivery_queue WHERE delivered = true AND delivered_at > NOW() - INTERVAL '24 hours') as bottles_delivered_24h,
  (SELECT COUNT(*) FROM bottle_delivery_queue WHERE delivered = false) as pending_deliveries,
  (SELECT COUNT(*) FROM user_blocks) as total_blocks;

-- Delivery performance
SELECT 
  AVG(EXTRACT(EPOCH FROM (delivered_at - scheduled_delivery_at))) / 60 as avg_delay_minutes,
  MAX(EXTRACT(EPOCH FROM (delivered_at - scheduled_delivery_at))) / 60 as max_delay_minutes
FROM bottle_delivery_queue
WHERE delivered = true 
AND delivered_at > NOW() - INTERVAL '24 hours';
```

---

## ✨ Success Criteria

Your system is working correctly if:

- ✅ Cron job runs every minute
- ✅ Bottles match within seconds
- ✅ Bottles deliver within 1-5 minutes
- ✅ Status badges update correctly (🌊 → 📬)
- ✅ Settings save and persist
- ✅ Blocking works correctly
- ✅ Match scores are calculated (> 0)

---

## 🎯 Next Steps

1. **Create Test Users** - At least 2-3 users with different preferences
2. **Test Matching** - Send bottles between users
3. **Monitor Logs** - Check cron job and Edge Function logs
4. **Add Navigation** - Link settings screen to profile tab
5. **Add Notifications** - Implement Supabase Realtime for bottle arrival

The system is ready for testing!
