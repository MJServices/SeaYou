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

      if (!userId) {
        throw new Error("No client_reference_id (userId) found in session.");
      }

      const supabaseClient = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      );

      // Reward mapping based on Payment Link IDs provided by user
      if (paymentLinkId === "eVq9ATc6i1l786cdC62Nq01") {
        const { error } = await supabaseClient.rpc("increment_scrolls", {
          user_id: userId,
          amount: 3,
        });
        if (error) throw error;
        console.log(`✅ Credited 3 scrolls to user ${userId}`);
      } else if (paymentLinkId === "eVq7sL1rEe7T86c7dI2Nq04") {
        const { error } = await supabaseClient.rpc("increment_scrolls", {
          user_id: userId,
          amount: 10,
        });
        if (error) throw error;
        console.log(`✅ Credited 10 scrolls to user ${userId}`);
      } else if (paymentLinkId === "3cIeVd8U6e7T728gOi2Nq03") {
        const { error } = await supabaseClient.rpc("increment_scrolls", {
          user_id: userId,
          amount: 30,
        });
        if (error) throw error;
        console.log(`✅ Credited 30 scrolls to user ${userId}`);
      } else if (paymentLinkId === "3cI28r0nAd3PdqwfKe2Nq02") {
        // Upgrade to Premium
        const { error: profileError } = await supabaseClient
          .from("profiles")
          .update({ is_premium: true, tier: "premium" })
          .eq("id", userId);

        if (profileError) throw profileError;

        const now = new Date();
        const expiresAt = new Date();
        expiresAt.setDate(now.getDate() + 30);

        const { error: entitlementError } = await supabaseClient
          .from("entitlements")
          .upsert({
            user_id: userId,
            tier: "premium",
            source: "stripe",
            expires_at: expiresAt.toISOString(),
            updated_at: now.toISOString(),
          });

        if (entitlementError) throw entitlementError;
        console.log(`✅ Upgraded user ${userId} to Premium`);
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
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
