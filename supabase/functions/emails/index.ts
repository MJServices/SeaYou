// Stub email sender using Resend via HTTP
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.3";

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function sendEmail(to: string, subject: string, html: string) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from: 'SeaYou <noreply@seayou.app>', to, subject, html })
  });
  return res.ok;
}

serve(async (req) => {
  try {
    const body = await req.json();
    const userId = body.user_id as string;
    const template = body.template as string; // 'welcome_premium' | 'upgrade_elite' | 'expiration_warning'

    const { data: profile } = await supabase.from('profiles').select('email, full_name').eq('id', userId).single();
    const email = profile?.email as string | undefined;
    const name = (profile?.full_name as string | undefined) ?? 'SeaYou user';
    if (!email) return new Response(JSON.stringify({ ok: false, error: 'No email' }), { status: 400 });

    const html = `<div style="font-family:Montserrat"><h1>SeaYou</h1><p>Hello ${name},</p><p>Thanks for being with us.</p></div>`;
    const subject = template === 'upgrade_elite' ? 'Welcome to SeaYou Elite' : 'Welcome to SeaYou Premium';
    const ok = await sendEmail(email, subject, html);

    return new Response(JSON.stringify({ ok }), { status: ok ? 200 : 500 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: `${e}` }), { status: 500 });
  }
});

