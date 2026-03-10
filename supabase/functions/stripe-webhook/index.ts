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

    if (event.type === "checkout.session.completed") {
      const session = event.data.object;
      const userId = session.client_reference_id;
      const paymentLinkId = session.payment_link;

      console.log(
        `📦 Fulfillment started for User: ${userId}, PaymentLink: ${paymentLinkId}`,
      );

      const supabaseClient = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      );

      let identifiedUserId = userId;

      // Fallback: If no client_reference_id, try to find user by email
      if (!identifiedUserId && session.customer_details?.email) {
        console.log(
          `🔍 No client_reference_id. Searching for user by email: ${session.customer_details.email}`,
        );
        const { data: userData, error: userError } = await supabaseClient
          .from("profiles")
          .select("id")
          .eq("email", session.customer_details.email)
          .single();

        if (userData) {
          identifiedUserId = userData.id;
          console.log(`✅ Found user by email: ${identifiedUserId}`);
        } else {
          console.warn(
            `❓ Could not find user with email: ${session.customer_details.email}`,
          );
        }
      }

      if (!identifiedUserId) {
        throw new Error(
          "Could not identify user (no client_reference_id and no matching email).",
        );
      }

      // Reward mapping based on Payment Link IDs provided by user
      if (
        paymentLinkId === "test_5kQ00ifqJawN6Gv6kW4gg03" ||
        paymentLinkId === "plink_1T8eTpAntToJSaE8ribE8lyv" ||
        paymentLinkId === "plink_1T8eZBAntToJSaE8dSHr3qcl"
      ) {
        console.log(`💎 Processing 3 Scrolls pack...`);
        const { error } = await supabaseClient.rpc("increment_scrolls", {
          user_id: identifiedUserId,
          amount: 3,
        });
        if (error) throw error;
        console.log(`✅ Credited 3 scrolls to user ${identifiedUserId}`);
      } else if (
        paymentLinkId === "test_dRm7sK2DX9sJfd1eRs4gg02" ||
        paymentLinkId === "plink_1T8eYzAntToJSaE8Ku0Cdsyj" ||
        paymentLinkId === "plink_1T8eZSAntToJSaE8eO2hDeuz"
      ) {
        console.log(`💎 Processing 10 Scrolls pack...`);
        const { error } = await supabaseClient.rpc("increment_scrolls", {
          user_id: identifiedUserId,
          amount: 10,
        });
        if (error) throw error;
        console.log(`✅ Credited 10 scrolls to user ${identifiedUserId}`);
      } else if (
        paymentLinkId === "test_7sY00i2DX20h8OD8t44gg01" ||
        paymentLinkId === "plink_1T8eYgAntToJSaE8kYWHFrnv" ||
        paymentLinkId === "plink_1T8eZkAntToJSaE8NIFKyTTm"
      ) {
        console.log(`💎 Processing 30 Scrolls pack...`);
        const { error } = await supabaseClient.rpc("increment_scrolls", {
          user_id: identifiedUserId,
          amount: 30,
        });
        if (error) throw error;
        console.log(`✅ Credited 30 scrolls to user ${identifiedUserId}`);
      } else if (
        paymentLinkId === "test_cNi4gybatdIZfd15gS4gg04" ||
        paymentLinkId === "plink_1T8eZQAntToJSaE8ODuenmeU" ||
        paymentLinkId === "test_14AaEWfqJ9sJc0P24G4gg00"
      ) {
        console.log(`👑 Processing Premium Upgrade...`);
        // Upgrade to Premium
        const { error: profileError } = await supabaseClient
          .from("profiles")
          .update({ is_premium: true, tier: "premium" })
          .eq("id", identifiedUserId);

        if (profileError) throw profileError;

        const now = new Date();
        const expiresAt = new Date();
        expiresAt.setDate(now.getDate() + 30);

        const { error: entitlementError } = await supabaseClient
          .from("entitlements")
          .upsert({
            user_id: identifiedUserId,
            tier: "premium",
            source: "stripe",
            expires_at: expiresAt.toISOString(),
            updated_at: now.toISOString(),
          });

        if (entitlementError) throw entitlementError;
        console.log(`✅ Upgraded user ${identifiedUserId} to Premium`);
      } else {
        console.warn(
          `❓ Unknown Payment Link ID: ${paymentLinkId}. No reward granted.`,
        );
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error(`❌ Webhook Error: ${err.message}`);
    // Log the raw body/event if possible for high-level debug
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
