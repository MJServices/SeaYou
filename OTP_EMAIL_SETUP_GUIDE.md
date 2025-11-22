# OTP Email Setup Guide for SeaYou App

## ✅ What's Been Fixed

Your Flutter app is now properly configured to send **OTP (One-Time Password) codes via email** instead of confirmation links. Here's what was updated:

### 1. **Auth Service** (`lib/services/auth_service.dart`)
- ✅ Uses `signInWithOtp()` to send 6-digit OTP codes via email
- ✅ Explicitly sets `shouldCreateUser: true` to create new users
- ✅ Uses `emailRedirectTo: null` for pure OTP flow (no magic links)

### 2. **Verification Screen** (`lib/screens/verification_screen.dart`)
- ✅ Added countdown timer (60 seconds) before allowing resend
- ✅ Added "Resend OTP" functionality
- ✅ Improved error messages for expired/invalid codes
- ✅ Better user feedback with loading states
- ✅ Proper timer cleanup to prevent memory leaks

### 3. **Create Account Screen** (`lib/screens/create_account_screen.dart`)
- ✅ Already correctly calling `signInWithEmail()` which triggers OTP sending
- ✅ Proper error handling

---

## 🔧 Required Supabase Configuration

To ensure OTP codes are sent via email (not confirmation links), you need to configure your Supabase project:

### Step 1: Access Supabase Dashboard
1. Go to: https://app.supabase.com/project/nenugkyvcewatuddrwvf
2. Navigate to **Authentication** → **Email Templates**

### Step 2: Configure Email Template for OTP
Find the **"Magic Link"** or **"Confirm signup"** template and update it to display the OTP token:

**Example Email Template:**
```html
<h2>Your Verification Code</h2>
<p>Hi there!</p>
<p>Your verification code for SeaYou is:</p>
<h1 style="font-size: 32px; letter-spacing: 8px; font-weight: bold;">{{ .Token }}</h1>
<p>This code will expire in 60 seconds.</p>
<p>If you didn't request this code, please ignore this email.</p>
```

**Important:** Make sure the template includes `{{ .Token }}` to display the 6-digit OTP code.

### Step 3: Verify Auth Settings
1. Go to **Authentication** → **Settings**
2. Check these settings:
   - ✅ **Enable email confirmations**: Should be enabled
   - ✅ **OTP Expiry**: Default is 60 seconds (matches our countdown timer)
   - ✅ **Email provider**: Make sure you have an email provider configured (SMTP or Supabase default)

### Step 4: Test Email Delivery
1. Make sure your Supabase project has email sending configured
2. For production, configure a custom SMTP provider (SendGrid, AWS SES, etc.)
3. For development, Supabase's default email service should work

---

## 📱 How the Flow Works Now

1. **User enters email** on Create Account screen
2. **App calls** `AuthService().signInWithEmail(email)`
3. **Supabase sends** a 6-digit OTP code to the user's email
4. **User receives email** with the OTP code (e.g., "123456")
5. **User enters** the 6-digit code on Verification screen
6. **App verifies** the code using `AuthService().verifyOtp(email, code)`
7. **If valid**, user proceeds to Create Password screen
8. **If invalid/expired**, user sees error message and can resend

---

## 🎯 Features Added

### Countdown Timer
- 60-second countdown before allowing resend
- Displays as "Resend code in 00:XX"
- After countdown, shows "Didn't receive the code? Resend"

### Resend OTP
- Users can request a new OTP after 60 seconds
- Countdown resets when new OTP is sent
- Success/error feedback via SnackBar

### Better Error Messages
- "Invalid or expired code. Please try again."
- "Code has expired. Please request a new one."
- "Invalid code. Please check and try again."

### Loading States
- Shows "Verifying code..." while checking OTP
- Visual feedback during verification process

---

## 🐛 Troubleshooting

### Issue: Still receiving confirmation links instead of OTP codes
**Solution:** Update the email template in Supabase to include `{{ .Token }}` instead of `{{ .ConfirmationURL }}`

### Issue: OTP codes not arriving
**Solution:** 
- Check Supabase email logs in Dashboard → Authentication → Logs
- Verify email provider is configured
- Check spam folder
- For production, set up custom SMTP

### Issue: "Invalid code" error even with correct code
**Solution:**
- Code might have expired (60 seconds)
- Request a new code using "Resend"
- Check that Supabase OTP expiry matches your timer

### Issue: Timer not working
**Solution:** Already fixed! Timer is properly initialized in `initState()` and cleaned up in `dispose()`

---

## 📝 Testing Checklist

- [ ] Enter email on Create Account screen
- [ ] Verify OTP email is received (check inbox and spam)
- [ ] Email contains 6-digit code (not a link)
- [ ] Enter correct code → should proceed to Create Password
- [ ] Enter wrong code → should show error message
- [ ] Wait for code to expire → should show "expired" message
- [ ] Click "Resend" → should receive new code
- [ ] Countdown timer should work correctly

---

## 🚀 Next Steps

1. **Configure Supabase email template** (most important!)
2. **Test the OTP flow** with a real email address
3. **Set up production SMTP** for reliable email delivery
4. **Monitor email delivery** in Supabase logs

---

## 📧 Email Template Variables

Available variables in Supabase email templates:
- `{{ .Token }}` - The 6-digit OTP code
- `{{ .Email }}` - User's email address
- `{{ .SiteURL }}` - Your site URL
- `{{ .TokenHash }}` - Hashed token (for magic links)
- `{{ .ConfirmationURL }}` - Full confirmation URL (for magic links)

**For OTP flow, use `{{ .Token }}` only!**

---

## ✨ Summary

Your app is now properly configured to send OTP codes via email! The main thing you need to do is **update the Supabase email template** to display `{{ .Token }}` instead of a confirmation link. Once that's done, users will receive a 6-digit code they can enter in your app.

If you have any issues, check the Supabase Authentication logs and verify your email provider is working correctly.
