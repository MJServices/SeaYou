// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    const { email: rawEmail } = await req.json();
    const email = rawEmail?.toLowerCase().trim();
    if (!email) throw new Error("Email required");

    // Use Service Role to bypass RLS
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Check profiles
    const { data, error } = await supabase
      .from("profiles")
      .select("email")
      .eq("email", email)
      .maybeSingle();

    if (error) throw error;

    let exists = !!data;

    if (!exists) {
      // 2. Fallback check in auth.users (to capture users who verified OTP but didn't finish onboarding)
      try {
        const { data: { users }, error: listError } = await supabase.auth.admin.listUsers();
        if (!listError && users) {
          const user = users.find((u) => u.email?.toLowerCase() === email);
          if (user) {
            exists = true;
            console.log(`👤 check-email: User found in auth.users but missing profile: ${email}`);
          }
        }
      } catch (e) {
        console.error("check-email: Fallback user lookup failed:", e);
      }
    }

    return new Response(JSON.stringify({ exists }), {
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
