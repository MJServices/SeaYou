# Disable OTP for Testing

To make testing easier without checking emails for OTP codes, you can temporarily disable email confirmation in Supabase:

## Steps to Disable Email Confirmation:

1. Go to your Supabase Dashboard
2. Navigate to **Authentication** → **Providers** → **Email**
3. Scroll down to **Email Confirmation**
4. **Uncheck** "Enable email confirmations"
5. Click **Save**

## Alternative: Use a Test Email Service

If you want to keep email confirmation enabled but make testing easier:

1. Use a service like **Mailinator** or **Temp Mail**
2. Sign up with emails like: `test1@mailinator.com`, `test2@mailinator.com`, etc.
3. Check OTP codes at: https://www.mailinator.com/

## Re-enable Before Production

**IMPORTANT:** Remember to re-enable email confirmation before going to production!

## Current Code Changes

I've added debug logging to the OTP verification in `auth_service.dart` that shows when OTP is being verified. The code will still try to verify real OTPs, but with email confirmation disabled in Supabase, users will be automatically signed in without needing to enter an OTP.

## Test Users Created

Run `supabase/seed_test_users.sql` to create 20 test users with diverse profiles. These users will be available for bottle matching when you send bottles.
