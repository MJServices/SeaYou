# 🔧 SUPABASE EMAIL TEMPLATE FIX - STEP BY STEP

## Problem
You're receiving a confirmation link instead of an OTP code in emails.

## Solution
Update the Supabase email template to display the OTP token.

---

## 📋 EXACT STEPS TO FIX

### Step 1: Access Supabase Dashboard
1. Open your browser
2. Go to: **https://app.supabase.com/project/nenugkyvcewatuddrwvf/auth/templates**
3. Log in if needed

### Step 2: Select the Correct Template
You'll see several email templates. Click on **"Magic Link"** template.

### Step 3: Replace the Template Content
1. Click "Edit" on the Magic Link template
2. **DELETE ALL** the existing content
3. **COPY** the content from `SUPABASE_EMAIL_TEMPLATE.html` (in your project folder)
4. **PASTE** it into the template editor
5. Click **"Save"**

---

## 🎯 KEY POINT: The Template MUST Include

The most important line in the template is:

```html
{{ .Token }}
```

This displays the 6-digit OTP code. **DO NOT use** `{{ .ConfirmationURL }}` or any link variables.

---

## 📧 ALTERNATIVE: Simple Text-Only Template

If you prefer a simpler email, use this minimal template instead:

```html
<h2>SeaYou Verification Code</h2>

<p>Hi there!</p>

<p>Your verification code is:</p>

<h1 style="font-size: 48px; letter-spacing: 10px; color: #0AC5C5; font-family: monospace;">{{ .Token }}</h1>

<p>This code will expire in 60 seconds.</p>

<p>If you didn't request this code, please ignore this email.</p>

<hr>
<p style="color: #999; font-size: 12px;">© 2025 SeaYou</p>
```

---

## ✅ VERIFICATION

After updating the template:

1. **Test the flow:**
   - Run your app
   - Enter an email on Create Account screen
   - Check your email inbox

2. **You should see:**
   - ✅ A 6-digit code (e.g., "123456")
   - ❌ NO confirmation link
   - ❌ NO "Click here to confirm" button

3. **If you still see a link:**
   - Make sure you edited the **"Magic Link"** template
   - Verify you saved the changes
   - Try clearing your email cache or use a different email

---

## 🔍 TROUBLESHOOTING

### Issue: Still seeing confirmation links
**Solution:** 
- Check you're editing the correct template (Magic Link)
- Make sure the template includes `{{ .Token }}` not `{{ .ConfirmationURL }}`
- Save the template and try again

### Issue: No email received at all
**Solution:**
- Check spam folder
- Verify email provider is configured in Supabase
- Check Supabase logs: Authentication → Logs

### Issue: Template won't save
**Solution:**
- Make sure the HTML is valid
- Try the simpler text-only template first
- Check for any error messages in Supabase

---

## 📁 FILES IN YOUR PROJECT

I've created two files to help you:

1. **SUPABASE_EMAIL_TEMPLATE.html** - Beautiful, professional email template
2. **SUPABASE_TEMPLATE_FIX_GUIDE.md** - This guide

---

## 🎨 TEMPLATE FEATURES

The email template I created includes:
- ✅ SeaYou branding with your brand colors (#0AC5C5)
- ✅ Large, easy-to-read OTP code
- ✅ Professional design
- ✅ Mobile-responsive
- ✅ 60-second expiry notice
- ✅ Security message
- ❌ NO confirmation links
- ❌ NO magic links

---

## 🚀 NEXT STEPS

1. Copy the template from `SUPABASE_EMAIL_TEMPLATE.html`
2. Paste it into Supabase Magic Link template
3. Save
4. Test with your app
5. Enjoy OTP-only authentication! 🎉

---

## 💡 IMPORTANT NOTES

- The template uses `{{ .Token }}` which is a Supabase variable
- This variable automatically contains the 6-digit OTP code
- The code expires in 60 seconds (matches your app's countdown timer)
- Users can request a new code using the "Resend" button in your app

---

## 📞 STILL HAVING ISSUES?

If you're still seeing confirmation links after following these steps:

1. Double-check you're editing the **Magic Link** template (not Confirm Signup)
2. Make sure you clicked **Save** after pasting the template
3. Try sending a new verification email (old emails might still have the old template)
4. Clear your email cache or test with a different email address

---

**That's it! Your Supabase should now send OTP codes instead of confirmation links.** 🎉
