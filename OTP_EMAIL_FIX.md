# OTP Email Issue - Troubleshooting Guide

## Problem
You're receiving emails when signing up, but the OTP code is not appearing in the email body.

## Root Cause
The Supabase email template is likely not configured to display the OTP token. By default, Supabase might be sending a magic link instead of showing the 6-digit OTP code.

## Solution Steps

### 1. Configure Supabase Email Template

1. **Access Supabase Dashboard**:
   - Go to: https://nenugkyvcewatuddrwvf.supabase.co
   - Navigate to **Authentication** → **Email Templates**

2. **Find the OTP Email Template**:
   - Look for "Magic Link" or "Confirm signup" template
   - This is the template used when `signInWithOtp()` is called

3. **Update the Email Template**:
   Replace or modify the template to include the `{{ .Token }}` variable:

   ```html
   <h2>Welcome to SeaYou!</h2>
   <p>Your verification code is:</p>
   <h1 style="font-size: 32px; font-weight: bold; margin: 20px 0; color: #0AC5C5;">{{ .Token }}</h1>
   <p>This code will expire in 60 minutes.</p>
   <p>If you didn't request this code, you can safely ignore this email.</p>
   ```

   **Important**: The `{{ .Token }}` variable is what displays the 6-digit OTP code.

4. **Save the Template**:
   - Click "Save" to apply the changes
   - The changes take effect immediately

### 2. Verify Email Settings

1. Go to **Authentication** → **Settings** in your Supabase dashboard
2. Under **Email Auth**, ensure:
   - ✅ "Enable email confirmations" is ON
   - ✅ "Secure email change" is configured as needed
   - ✅ Check the "OTP expiration" time (default is 3600 seconds / 60 minutes)

### 3. Test the Fix

1. **Hot Reload Your App**:
   - The Flutter app is already running with `flutter run`
   - Press `r` in the terminal to hot reload
   - Or press `R` for a full restart

2. **Try Signing Up**:
   - Go to the Create Account screen
   - Enter a test email
   - Click "Send verification code"

3. **Check the Logs**:
   - Look at the Flutter console output
   - You should see: `🔐 Sending OTP to: [email]`
   - Followed by: `✅ OTP sent successfully to: [email]`

4. **Check Your Email**:
   - The email should now contain the 6-digit OTP code
   - Enter this code in the verification screen

### 4. Debug Logging Added

I've added debug logging to help track the OTP sending process:

- `🔐 Sending OTP to: [email]` - When OTP sending starts
- `✅ OTP sent successfully to: [email]` - When OTP is sent successfully
- `❌ Error sending OTP: [error]` - If there's an error
- `🔍 Checking if email exists: [email]` - For sign-in flow
- `❌ Email not found: [email]` - If email doesn't exist during sign-in

Check your Flutter console/terminal for these messages.

## Common Issues

### Issue 1: Email Template Not Updated
**Symptom**: Still receiving emails without OTP
**Solution**: Double-check that you saved the email template in Supabase dashboard

### Issue 2: Wrong Email Template
**Symptom**: OTP still not showing
**Solution**: Make sure you're editing the correct template. For OTP, it's usually the "Magic Link" template, not "Confirm signup"

### Issue 3: Email Provider Blocking
**Symptom**: Not receiving emails at all
**Solution**: 
- Check spam/junk folder
- Try a different email provider (Gmail, Outlook, etc.)
- Check Supabase logs for email delivery failures

### Issue 4: OTP Expiration
**Symptom**: OTP code doesn't work
**Solution**: The OTP expires after 60 minutes by default. Request a new code using the "Resend code" option

## Testing Checklist

- [ ] Updated Supabase email template with `{{ .Token }}`
- [ ] Saved the template in Supabase dashboard
- [ ] Hot reloaded the Flutter app
- [ ] Tested sign-up flow
- [ ] Received email with visible OTP code
- [ ] Successfully verified OTP
- [ ] Checked console logs for debug messages

## Next Steps

1. Update the Supabase email template as described above
2. Test the sign-up flow again
3. If you still don't see the OTP, check the Supabase dashboard logs:
   - Go to **Logs** → **Auth Logs**
   - Look for any errors related to email sending

## Need More Help?

If the issue persists after following these steps:
1. Share the console logs (the emoji messages)
2. Check if you can see the email template in Supabase
3. Verify that emails are being delivered (check spam folder)
