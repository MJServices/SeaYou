// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email: rawEmail, type = "signup" } = await req.json();
    const email = rawEmail?.toLowerCase().trim();

    if (!email) {
      throw new Error("Email is required");
    }

    // 1. Generate 6-digit Code
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString(); // 15 mins

    // 2. Init Supabase Admin Client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 3. Store in DB
    const { error: dbError } = await supabase
      .from("verification_codes")
      .insert({
        email,
        code,
        type,
        expires_at: expiresAt,
      });

    if (dbError) {
      console.error("DB Error:", dbError);
      throw new Error("Failed to store verification code");
    }

    // 4. Send Email via Resend
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "SeaYou <noreply@seayou-app.com>", // Ensure this matches your Verified Domain
        to: email,
        subject: "Your Verification Code",
        html: `
          <h2>Verification Code</h2>
          <p>Your code is: <strong>${code}</strong></p>
          <p>It expires in 15 minutes.</p>
        `,
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error("Resend Error:", err);
      throw new Error("Failed to send email");
    }

    return new Response(JSON.stringify({ message: "OTP sent" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
