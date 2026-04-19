import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@12.0.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const STRIPE_WEBHOOK_SIGNING_SECRET =
  Deno.env.get("STRIPE_WEBHOOK_SIGNING_SECRET") ?? "";

serve(async (req: Request) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const stripe = new Stripe(STRIPE_SECRET_KEY, {
    apiVersion: "2022-11-15",
    httpClient: Stripe.createFetchHttpClient(),
  });

  try {
    const signature = req.headers.get("stripe-signature");
    const body = await req.text();
    let event;

    if (STRIPE_WEBHOOK_SIGNING_SECRET && signature) {
      event = await stripe.webhooks.constructEventAsync(
        body,
        signature,
        STRIPE_WEBHOOK_SIGNING_SECRET,
      );
    } else {
      console.log(
        "⚠️ Signature verification skipped. Ensure STRIPE_WEBHOOK_SIGNING_SECRET is set for production.",
      );
      event = JSON.parse(body);
    }

    console.log(`🔔 Event received: ${event.type}`);

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    let result = { status: "ignored" };

    // --- HANDLING EVENTS ---

    if (event.type === "checkout.session.completed" || event.type === "invoice.payment_succeeded") {
      const session = event.data.object;
      
      // Identify User
      let userId = session.client_reference_id || session.metadata?.client_reference_id;
      let email = session.customer_details?.email || session.customer_email;

      // For invoice events, the user might be found via the customer ID 
      // if we have it mapped, or via the subscription metadata
      if (!userId && session.subscription) {
        const subscription = await stripe.subscriptions.retrieve(session.subscription);
        userId = subscription.metadata?.client_reference_id;
        if (!email) email = subscription.metadata?.email;
      }

      console.log(`📦 Fulfillment logic starting. User: ${userId}, Email: ${email}`);

      let identifiedUserId = userId;

      // Fallback: If no userId, try to find user by email
      if (!identifiedUserId && email) {
        console.log(`🔍 Searching for user by email: ${email}`);
        const { data: userData } = await supabaseClient
          .from("profiles")
          .select("id")
          .eq("email", email)
          .single();

        if (userData) {
          identifiedUserId = userData.id;
          console.log(`✅ Found user by email: ${identifiedUserId}`);
        }
      }

      if (!identifiedUserId) {
        console.error("❌ Could not identify user.");
        return new Response(JSON.stringify({ error: "User not identified" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // --- REWARD LOGIC ---
      
      const paymentLinkId = session.payment_link;
      const amountTotal = session.amount_total ?? session.amount_paid ?? 0;
      const metadata = session.metadata ?? {};
      const packType = metadata.pack_type || metadata.scroll_amount;

      console.log(`💰 Amount: ${amountTotal}, Link: ${paymentLinkId}, PackType: ${packType}`);

      if (
        packType === "scroll_3" ||
        packType === "scrolls_3" ||
        paymentLinkId === "plink_1SyUdAF2hBJlS4m6LICKTeWv" ||
        (paymentLinkId && ["test_5kQ00ifqJawN6Gv6kW4gg03", "plink_1T8eTpAntToJSaE8ribE8lyv"].includes(paymentLinkId)) ||
        amountTotal === 299 || amountTotal === 897 // Supporting adaptive pricing / multiples
      ) {
        console.log(`💎 Granting 3 Scrolls...`);
        const { error } = await supabaseClient.rpc("increment_scrolls", {
          user_id: identifiedUserId,
          amount: 3,
        });
        if (error) throw error;
        result = { status: "success", granted: "3_scrolls" };
      } 
      else if (
        packType === "scroll_10" ||
        packType === "scrolls_10" ||
        paymentLinkId === "plink_1SyrouF2hBJlS4m68QjOKYly" ||
        (paymentLinkId && ["test_dRm7sK2DX9sJfd1eRs4gg02", "plink_1T8eYzAntToJSaE8Ku0Cdsyj"].includes(paymentLinkId)) ||
        amountTotal === 1490
      ) {
        console.log(`💎 Granting 10 Scrolls...`);
        const { error } = await supabaseClient.rpc("increment_scrolls", {
          user_id: identifiedUserId,
          amount: 10,
        });
        if (error) throw error;
        result = { status: "success", granted: "10_scrolls" };
      }
      else if (
        packType === "scroll_30" ||
        packType === "scrolls_30" ||
        paymentLinkId === "plink_1Syro6F2hBJlS4m6bBuQpYBy" ||
        (paymentLinkId && ["test_7sY00i2DX20h8OD8t44gg01"].includes(paymentLinkId)) ||
        amountTotal === 3600
      ) {
        console.log(`💎 Granting 30 Scrolls...`);
        const { error } = await supabaseClient.rpc("increment_scrolls", {
          user_id: identifiedUserId,
          amount: 30,
        });
        if (error) throw error;
        result = { status: "success", granted: "30_scrolls" };
      }
      else if (
        packType === "premium" ||
        paymentLinkId === "plink_1SyVisF2hBJlS4m6Kg5GVCA8" ||
        (paymentLinkId && ["test_cNi4gybatdIZfd15gS4gg04", "test_14AaEWfqJ9sJc0P24G4gg00"].includes(paymentLinkId)) ||
        session.subscription // If it's a subscription event, it's likely premium
      ) {
        console.log(`👑 Granting Premium Upgrade...`);
        const { error: profileError } = await supabaseClient
          .from("profiles")
          .update({ is_premium: true, tier: "premium" })
          .eq("id", identifiedUserId);
        if (profileError) throw profileError;

        const now = new Date();
        const expiresAt = new Date();
        expiresAt.setDate(now.getDate() + 32); // Grace period

        await supabaseClient.from("entitlements").upsert({
          user_id: identifiedUserId,
          tier: "premium",
          source: "stripe",
          expires_at: expiresAt.toISOString(),
          updated_at: now.toISOString(),
        });
        result = { status: "success", granted: "premium" };
      } else {
        console.warn(`❓ Unknown criteria. No reward granted.`);
        result = { status: "warning", message: "Unknown fulfillment criteria" };
      }
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error(`❌ Webhook Error: ${err.message}`);
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
