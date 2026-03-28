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
    const { email: rawEmail, code } = await req.json();
    const email = rawEmail?.toLowerCase().trim();

    if (!email || !code) {
      throw new Error("Email and Code are required");
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Verify Code
    const now = new Date().toISOString();
    console.log(`🔍 Searching for Code: [${code}] for Email: [${email}] (Now: ${now})`);

    // 1. Verify Code with full matching
    const { data: codes, error: queryError } = await supabase
      .from("verification_codes")
      .select("*")
      .eq("email", email)
      .eq("code", code.toString())
      .gt("expires_at", now)
      .limit(1);

    if (queryError) {
      console.error("Query Error:", queryError);
      throw queryError;
    }

    if (!codes || codes.length === 0) {
      console.log(`❌ Code not found or expired for ${email}. Let's see what's in the DB:`);
      
      // DEBUG: Wide search for this email to see what's going on
      const { data: allCodes } = await supabase
        .from("verification_codes")
        .select("*")
        .eq("email", email)
        .order("created_at", { ascending: false });
      
      if (allCodes && allCodes.length > 0) {
        allCodes.forEach(c => {
          console.log(`   - Found: Code[${c.code}] Exp[${c.expires_at}] Type[${c.type}]`);
        });
      } else {
        console.log(`   - NO records found at all for this email.`);
      }

      throw new Error("Invalid or expired code.");
    }

    // 2. Mark User as Verified
    const { error: updateError } = await supabase
      .from("profiles")
      .update({ is_verified: true })
      .eq("email", email);

    if (updateError) {
      console.error("Profile Update Error:", updateError);
      // Not fatal if profile doesn't exist yet
    }

    // 3. Delete used code
    await supabase.from("verification_codes").delete().eq("id", codes[0].id);

    // 4. Ensure User Exists in auth.users
    let user;
    let isNewUser = false;
    const tempPassword = Math.random().toString(12).slice(-6) + Math.random().toString(12).slice(-6);
    
    // First, try to get the user. We use listUsers() and find() as it's the most compatible 
    // way across different supabase-js versions in the Edge Runtime.
    try {
      const { data: { users }, error: listError } = await supabase.auth.admin.listUsers();
      if (listError) throw listError;
      
      user = users.find(u => u.email?.toLowerCase() === email);
      
      if (user) {
        console.log(`👤 Found existing user via listUsers: ${user.id}`);
      }
    } catch (e) {
      console.log("Error in user lookup fallback:", e);
    }
    
    if (!user) {
      // User not found, attempt to create
      console.log(`👤 Identifying as new user, attempting creation: ${email}`);
      const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
        email: email,
        password: tempPassword,
        email_confirm: true,
        user_metadata: { is_custom_otp: true }
      });

      if (createError) {
        // If it fails because they already exist, we must have missed them in the first lookup
        if (createError.message.includes("already been registered") || 
            createError.message.includes("already exists")) {
          console.log(`👤 User already exists after all, catching duplicate creation: ${email}`);
          const { data: { users: fallbackUsers } } = await supabase.auth.admin.listUsers();
          user = fallbackUsers?.find(u => u.email?.toLowerCase() === email);
          
          if (!user) throw createError; // Still not found? Throw the original error
          
          // If found now, proceed as existing user
          await supabase.auth.admin.updateUserById(user.id, { password: tempPassword });
          isNewUser = false;
        } else {
          throw createError;
        }
      } else {
        user = newUser.user;
        isNewUser = true;
        console.log(`✅ New user created successfully: ${user.id}`);
      }
    } else {
      // Existing user found, update password for this session
      console.log(`👤 Existing user identified: ${user.id}`);
      await supabase.auth.admin.updateUserById(user.id, { password: tempPassword });
      isNewUser = false;
    }

    return new Response(
      JSON.stringify({
        message: "Verified successfully",
        temp_password: tempPassword,
        verification_type: isNewUser ? "signup" : "login"
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
