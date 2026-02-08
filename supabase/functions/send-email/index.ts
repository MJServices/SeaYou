import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { to, subject, html } = await req.json();
    console.log(`📧 [Send Email] To: ${to} | Subject: ${subject}`);

    if (!RESEND_API_KEY) {
      console.error("❌ [Send Email] RESEND_API is missing!");
      throw new Error("RESEND_API is not configured");
    }

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "SeaYou <noreply@seayou-app.com>", // Update this to your verified domain
        to,
        subject,
        html,
      }),
    });

    const responseText = await res.text();
    console.log(
      `📨 [Send Email] Resend Response: ${res.status} ${responseText}`
    );

    if (!res.ok) {
      throw new Error(`Resend API Error: ${res.statusText} - ${responseText}`);
    }

    const data = JSON.parse(responseText);
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: res.ok ? 200 : 400,
    });
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
