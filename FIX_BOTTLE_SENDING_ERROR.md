# Fix: "Failed to Send Bottle" Error

## Problem
When trying to send a bottle following the TESTING_GUIDE.md instructions, you get an error: **"Failed to send bottle"**

## Root Cause
The database is missing required functions and tables that the bottle matching system needs:
- `increment_bottles_sent()` function
- `increment_bottles_received()` function  
- `mark_profile_active()` function
- `bottle_delivery_queue` table
- `user_blocks` table
- Several columns in the `profiles` and `sent_bottles` tables

## Solution

### Step 1: Run the SQL Fix Script

1. Open your Supabase project dashboard
2. Go to **SQL Editor**
3. Open the file: `supabase/fix_bottle_sending.sql`
4. Copy all the SQL code
5. Paste it into the Supabase SQL Editor
6. Click **Run** to execute

### Step 2: Verify the Fix

After running the script, you should see verification results at the bottom showing:
- ✅ 3 functions created (`increment_bottles_sent`, `increment_bottles_received`, `mark_profile_active`)
- ✅ 2 tables created (`bottle_delivery_queue`, `user_blocks`)
- ✅ 7 columns added to `profiles` table

### Step 3: Test Bottle Sending

1. Open the app
2. Click "Send Bottle" button
3. Create a text bottle
4. Click Preview → Send
5. You should see a success confirmation!

## What the Fix Does

The SQL script:

1. **Creates missing functions** that increment bottle counters and track user activity
2. **Adds missing columns** to the `profiles` table for tracking:
   - Last active timestamp
   - Daily and total bottle counts
   - User activity status
3. **Creates the delivery queue table** for the "floating in sea" effect
4. **Creates the user blocks table** for privacy features
5. **Sets up proper indexes and RLS policies** for security

## Common Issues After Fix

### Issue: Still getting errors
**Solution**: Make sure you ran the ENTIRE SQL script, not just parts of it.

### Issue: "No compatible users found"
**Solution**: You need at least 2 users in the database with compatible preferences. Create a second test account.

### Issue: Bottle stays "Floating" forever
**Solution**: This is expected! The bottle delivery system requires a cron job or Edge Function to deliver bottles after 1-5 minutes. See `TESTING_GUIDE.md` for manual delivery instructions.

## Next Steps

After fixing the database:
1. ✅ Test sending a bottle
2. ✅ Verify bottle appears in "Sent Bottles" with 🌊 Floating badge
3. ✅ Check the database to confirm the bottle was matched
4. ✅ Set up the delivery cron job (optional, for automatic delivery)

## Manual Delivery (For Testing)

If you want to manually deliver a bottle without waiting for the cron job:

```sql
-- Get the bottle ID from sent_bottles
SELECT id, status FROM sent_bottles ORDER BY created_at DESC LIMIT 1;

-- Manually deliver it (replace BOTTLE_ID and RECIPIENT_ID)
UPDATE sent_bottles
SET status = 'delivered', delivered_at = NOW()
WHERE id = 'BOTTLE_ID';

UPDATE bottle_delivery_queue
SET delivered = true, delivered_at = NOW()
WHERE sent_bottle_id = 'BOTTLE_ID';

SELECT increment_bottles_received('RECIPIENT_ID');
```

## Related Files
- `supabase/fix_bottle_sending.sql` - The fix script
- `bottle_matching_migration.md` - Full migration documentation
- `TESTING_GUIDE.md` - Testing instructions
- `lib/services/database_service.dart` - Database service code
- `lib/services/bottle_matching_service.dart` - Matching logic
