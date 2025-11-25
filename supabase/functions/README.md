# Supabase Edge Function Setup

## Bottle Delivery Function

This Edge Function automatically delivers bottles that are ready (scheduled delivery time has passed).

### Deployment Steps

1. **Install Supabase CLI** (if not already installed):
```bash
npm install -g supabase
```

2. **Login to Supabase**:
```bash
supabase login
```

3. **Link to your project**:
```bash
supabase link --project-ref YOUR_PROJECT_REF
```

4. **Deploy the function**:
```bash
supabase functions deploy bottle-delivery
```

5. **Set up Cron Job** (runs every minute):

Go to Supabase Dashboard → Database → Cron Jobs (pg_cron extension)

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create cron job to run every minute
SELECT cron.schedule(
  'bottle-delivery-job',
  '* * * * *',  -- Every minute
  $$
  SELECT
    net.http_post(
      url:='https://YOUR_PROJECT_REF.supabase.co/functions/v1/bottle-delivery',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
    ) as request_id;
  $$
);
```

### Alternative: Supabase Scheduler (Recommended)

If pg_cron is not available, use Supabase's built-in scheduler:

1. Go to Supabase Dashboard → Edge Functions
2. Click on `bottle-delivery` function
3. Go to "Invocations" tab
4. Click "Schedule"
5. Set schedule: `* * * * *` (every minute)

### Testing

Test the function manually:

```bash
curl -X POST 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/bottle-delivery' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json'
```

### Monitoring

Check function logs:
```bash
supabase functions logs bottle-delivery
```

Or in Supabase Dashboard → Edge Functions → bottle-delivery → Logs

### Environment Variables

The function automatically uses:
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (has admin access)

These are automatically available in Edge Functions.

### How It Works

1. Runs every minute (via cron job)
2. Queries `bottle_delivery_queue` for bottles ready to deliver
3. Updates `sent_bottles` status to 'delivered'
4. Marks queue items as delivered
5. Increments recipient's bottle counter
6. Returns summary of deliveries

### Expected Output

```json
{
  "success": true,
  "message": "Delivery check complete",
  "stats": {
    "checked": 5,
    "delivered": 3,
    "errors": 0
  },
  "timestamp": "2025-11-23T04:30:00.000Z"
}
```

### Troubleshooting

**Function not deploying?**
- Check Supabase CLI is installed: `supabase --version`
- Verify you're linked to correct project: `supabase projects list`

**Cron job not running?**
- Check pg_cron is enabled: `SELECT * FROM pg_extension WHERE extname = 'pg_cron';`
- View cron jobs: `SELECT * FROM cron.job;`
- Check cron logs: `SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;`

**Bottles not delivering?**
- Check function logs for errors
- Verify `bottle_delivery_queue` has pending bottles
- Ensure `scheduled_delivery_at` is in the past
- Check `increment_bottles_received` function exists

### Cost Considerations

- Edge Functions: Free tier includes 500K invocations/month
- Running every minute = ~43,800 invocations/month
- Well within free tier limits

### Next Steps

After deployment:
1. Send a test bottle
2. Wait 1-5 minutes
3. Check if status changes to 'delivered'
4. Verify recipient receives the bottle
