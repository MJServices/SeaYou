// @ts-nocheck
import { serve } from "std/http/server";
import { createClient } from "supabase";

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
    const { email, code } = await req.json();

    if (!email || !code) {
      throw new Error("Email and Code are required");
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Verify Code
    const { data: codes, error: queryError } = await supabase
      .from("verification_codes")
      .select("*")
      .eq("email", email)
      .eq("code", code)
      .gt("expires_at", new Date().toISOString())
      .limit(1);

    if (queryError) throw queryError;

    if (!codes || codes.length === 0) {
      throw new Error("Invalid or expired code.");
    }

    // 2. Mark User as Verified
    const { error: updateError } = await supabase
      .from("profiles")
      .update({ is_verified: true })
      .eq("email", email);

    if (updateError) {
      console.error("Profile Update Error:", updateError);
      throw new Error("Failed to verify user profile");
    }

    // 3. Delete used code (Optional but good for security)
    await supabase.from("verification_codes").delete().eq("id", codes[0].id);

    // 4. Generate Magic Link Token for Login
    // Since we verified the user via our custom OTP, we can now generate a token to log them in securely.
    const { data: linkData, error: linkError } =
      await supabase.auth.admin.generateLink({
        type: "magiclink",
        email: email,
      });

    if (linkError) {
      console.error("Generate Link Error:", linkError);
      throw new Error("Failed to generate login session");
    }

    // Extract the token (which acts as the OTP for magiclink type) from the action_link
    // The action_link format is usually: SITE_URL/verify?token=TOKEN&type=magiclink...
    const actionLink = linkData.properties?.action_link;
    let token = "";

    if (actionLink) {
      const url = new URL(actionLink);
      // Supabase usually puts the token in the 'token' query param
      token = url.searchParams.get("token") || "";
      // Alternatively, sometimes it's the 'hashed_token' in properties?
      // No, client verifyOtp needs the raw token.
    }

    if (!token) {
      console.error("Failed to extract token from link:", actionLink);
      // Fallback: This shouldn't happen if generateLink works standardly
      throw new Error("Failed to generate login token");
    }

    return new Response(
      JSON.stringify({
        message: "Verified successfully",
        session_token: token, // Send this to client to complete login
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
