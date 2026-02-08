import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface EmailData {
  token: string;
  token_hash: string;
  redirect_to: string;
  email_action_type:
    | "signup"
    | "recovery"
    | "invite"
    | "magiclink"
    | "email_change_current"
    | "email_change_new";
  site_url: string;
  token_new: string;
  token_hash_new: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    console.log(
      "🔍 [Auth Hook] Received payload:",
      JSON.stringify(body, null, 2)
    );

    const { user, email_data } = body;
    const { email_action_type, token, redirect_to, site_url } =
      email_data as EmailData;

    console.log(
      `👤 [Auth Hook] Action: ${email_action_type} | User: ${user.email}`
    );

    if (!RESEND_API_KEY) {
      console.error("❌ [Auth Hook] RESEND_API is missing!");
      throw new Error("RESEND_API is not configured");
    }

    // Construct the URL
    // Standard Supabase verifies at /auth/v1/verify
    // But since we are handling sending, we usually point to our own app or the Supabase handler
    // Actually, simply constructing the link as Supabase WOULD have done:
    const params = new URLSearchParams({
      token,
      type: email_action_type,
      redirect_to: redirect_to || site_url,
    });

    // IMPORTANT: Verify where your Verify endpoint is.
    // Usually it is: <Project URL>/auth/v1/verify
    // We can infer Project URL or set it in Env.
    // For now, let's assume we pass the full constructed link if strictly needed,
    // OR just use the standard format.
    // To remain generic, we'll try to use site_url mostly, but standard verify link is best.
    const verifyLink = `${site_url}/auth/v1/verify?${params.toString()}`;
    console.log(`🔗 [Auth Hook] Generated Link: ${verifyLink}`);

    let subject = "Confirm your account";
    let html = "";

    // Template Logic
    switch (email_action_type) {
      case "signup":
        subject = "Welcome to SeaYou! Confirm your signup";
        html = `
          <h2>Welcome to SeaYou!</h2>
          <p>Please confirm your account by clicking the link below:</p>
          <a href="${verifyLink}">Confirm Signup</a>
          <p>Or use this code: <strong>${token}</strong> (if app supports code)</p>
        `;
        break;
      case "recovery":
        subject = "Reset your SeaYou Password";
        html = `
          <h2>Reset Password</h2>
          <p>Click the link to reset your password:</p>
          <a href="${verifyLink}">Reset Password</a>
        `;
        break;
      // Add other cases as needed
      default:
        subject = "SeaYou Notification";
        html = `<p>Action required: <a href="${verifyLink}">Click here</a></p>`;
    }

    // Send via Resend
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "SeaYou <noreply@seayou-app.com>", // Update with your Verified Domain
        to: user.email,
        subject: subject,
        html: html,
      }),
    });

    if (!res.ok) {
      const errorData = await res.text();
      console.error("Resend Error:", errorData);
      throw new Error(`Resend API Error: ${res.statusText}`);
    }

    const data = await res.json();
    console.log(`✅ [Auth Hook] Resend Success: ${res.status}`);

    // Return 200 to Supabase to acknowledge we handled it
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error: any) {
    console.error("Hook Error:", error);
    // Return 500 so Supabase knows it failed (and maybe retries or logs)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
