const url = (globalThis as any).Deno?.env.get("SUPABASE_URL") ?? "";
const key =
  (globalThis as any).Deno?.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

async function rest(path: string, init: RequestInit = {}) {
  const headers = {
    ...(init.headers || {}),
    apikey: key,
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json",
  } as Record<string, string>;
  const res = await fetch(`${url}/rest/v1/${path}`, { ...init, headers });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json();
}

async function rpc(fn: string, body: Record<string, unknown>) {
  return rest(`rpc/${fn}`, { method: "POST", body: JSON.stringify(body) });
}

async function processOutbox() {
  const outbox: any[] = await rest(`messages_outbox?order=created_at.asc`);
  if (!outbox || outbox.length === 0) return { processed: 0 };
  let processed = 0;
  for (const o of outbox) {
    const year = new Date().getUTCFullYear();
    const ageMin = o.min_age ?? 18;
    const ageMax = o.max_age ?? 100;
    const genderFilter = o.target_gender ?? "everyone";
    const candidates: any[] = await rest(
      `profiles?receive_bottles=eq.true&id=neq.${o.sender_id}&select=id,lat,lng,birth_year,gender,receive_bottles`
    );
    if (!candidates || candidates.length === 0) continue;
    const sender: any = (
      await rest(`profiles?id=eq.${o.sender_id}&select=lat,lng`)
    )[0];
    if (!sender || sender.lat == null || sender.lng == null) continue;

    const filtered = candidates.filter((c: any) => {
      if (c.birth_year == null) return false;
      const age = year - c.birth_year;
      if (age < ageMin || age > ageMax) return false;
      if (genderFilter !== "everyone" && c.gender !== genderFilter)
        return false;
      return c.lat != null && c.lng != null;
    });

    const distRows = await Promise.all(
      filtered.map(async (c: any) => {
        const d: any = await rpc("haversine_km", {
          lat1: sender.lat,
          lon1: sender.lng,
          lat2: c.lat,
          lon2: c.lng,
        });
        return { id: c.id, km: Number(d) };
      })
    );
    const within = distRows.filter(
      (r: any) => r.km != null && r.km <= (o.max_distance_km ?? 100)
    );
    if (within.length === 0) continue;
    const shuffled = within.sort(() => Math.random() - 0.5).slice(0, 20);

    for (const r of shuffled) {
      await rest(`matches`, {
        method: "POST",
        body: JSON.stringify({ outbox_id: o.id, recipient_id: r.id }),
      });
      await rest(`received_bottles`, {
        method: "POST",
        body: JSON.stringify({
          receiver_id: r.id,
          sender_id: o.sender_id,
          content_type: "text",
          message: o.text,
          is_read: false,
          is_replied: false,
        }),
      });
    }
    processed++;
  }
  return { processed };
}

addEventListener("fetch", (event: any) => {
  event.respondWith(
    processOutbox()
      .then(
        (res) =>
          new Response(JSON.stringify({ ok: true, ...res }), {
            headers: { "content-type": "application/json" },
          })
      )
      .catch(
        (e) =>
          new Response(JSON.stringify({ ok: false, error: String(e) }), {
            status: 500,
            headers: { "content-type": "application/json" },
          })
      )
  );
});
