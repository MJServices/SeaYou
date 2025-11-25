# Creating Test Users for Bottle Matching

Since we can't directly insert into `auth.users` via SQL, here are two approaches:

## Option 1: Update Existing Users (Quick & Easy)

Run this script to update your 3 existing users with diverse profiles:
```
supabase/update_existing_users_for_testing.sql
```

This will give each user different:
- Ages (24-26)
- Cities (Mumbai, Karachi)
- Expectations (Dating, Friendship)
- Interests (different sets)

Now when you send bottles from one account, they can match with the other 2 accounts!

## Option 2: Create New Test Users via Supabase Dashboard

If you want more test users:

1. **Disable Email Confirmation First:**
   - Go to Supabase Dashboard → Authentication → Providers → Email
   - Uncheck "Enable email confirmations"
   - Save

2. **Create Users via Dashboard:**
   - Go to Authentication → Users
   - Click "Add user" → "Create new user"
   - Enter email (e.g., `test1@example.com`)
   - Auto-generate password or set one
   - Click "Create user"

3. **Sign in to the App:**
   - Use the email you created
   - Since email confirmation is disabled, you can sign in immediately
   - Complete the onboarding to create their profile

4. **Repeat for Multiple Users:**
   - Create 5-10 test users this way
   - Each one will have a profile after onboarding

## Option 3: Use Real Email Addresses

Create accounts with real emails you have access to:
- Your personal emails
- Family/friends' emails (with permission)
- Temporary email services like Mailinator

## Testing Bottle Matching

Once you have multiple users:
1. Sign in as User A
2. Send a bottle
3. Check the logs - it should match with User B or C
4. Sign in as User B
5. Check received bottles - you should see the bottle from User A!

## Current Users Available

After running `update_existing_users_for_testing.sql`, you'll have:
- **Ayan** (c1497662...) - 25, Mumbai, Looking for Dating
- **MJ** (4c4d60d5...) - 24, Karachi, Looking for Friendship  
- **Minhaj** (7b52709a...) - 26, Karachi, Looking for Dating

These 3 users should be able to match with each other based on your matching algorithm!
