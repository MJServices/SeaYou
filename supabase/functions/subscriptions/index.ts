// Stub Stripe webhook handler for subscription entitlements
// Do not commit secrets. Configure environment variables in Supabase Functions UI.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.3";

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

serve(async (req) => {
  try {
    const event = await req.json();
    const type = event.type as string;
    const data = event.data?.object ?? {};

    // Map Stripe products/prices to tiers
    const customerId = data.customer as string | undefined;
    const userId = data.metadata?.user_id as string | undefined;
    const status = data.status as string | undefined;
    const currentPeriodEnd = data.current_period_end as number | undefined;

    if (!userId) return new Response(JSON.stringify({ ok: true }), { status: 200 });

    let tier = 'free';
    if (status === 'active' || status === 'trialing') tier = 'premium';
    if (data.items && Array.isArray(data.items)) {
      // Example mapping by price/product IDs (to be configured)
      const item = data.items[0];
      const priceId = item?.price?.id as string | undefined;
      if (priceId && priceId.startsWith('price_elite_')) tier = 'elite';
    }

    const expiresAt = currentPeriodEnd ? new Date(currentPeriodEnd * 1000).toISOString() : null;
    await supabase.from('entitlements').upsert({
      user_id: userId,
      tier,
      source: 'stripe',
      expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    });

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: `${e}` }), { status: 500 });
  }
});

