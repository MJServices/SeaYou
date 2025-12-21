addEventListener('fetch', (event: any) => {
  event.respondWith(handle(event.request));
});

async function handle(req: Request): Promise<Response> {
  try {
    const body = await req.json().catch(() => ({}));
    const photoId = body.photo_id as string | undefined;
    const imageUrl = body.image_url as string | undefined;
    const threshold = Number(body.threshold ?? 75);

    if (!photoId || !imageUrl) {
      return json({ ok: false, error: 'photo_id and image_url are required' }, 400);
    }

    // Simple heuristic placeholder score; replace with real AI call if configured
    let score = 60;
    const urlLower = imageUrl.toLowerCase();
    if (urlLower.includes('face') || urlLower.includes('avatar')) score = 85;

    const { url, key } = getEnv();
    await rest(url, key, 'profile_photos?id=eq.' + photoId, {
      method: 'PATCH',
      body: JSON.stringify({ ai_face_score: score, is_first_face_photo: true }),
    });

    const passed = score >= threshold;
    return json({ ok: true, score, passed });
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
}

function getEnv() {
  // Use globalThis.Deno to avoid type errors in non-Deno tooling
  const url = (globalThis as any).Deno?.env.get('SUPABASE_URL') ?? '';
  const key = (globalThis as any).Deno?.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  return { url, key };
}

async function rest(url: string, key: string, path: string, init: RequestInit) {
  const headers = {
    ...(init.headers || {}),
    apikey: key,
    Authorization: `Bearer ${key}`,
    'Content-Type': 'application/json',
  } as Record<string, string>;
  const res = await fetch(`${url}/rest/v1/${path}`, { ...init, headers });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json().catch(() => ({}));
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json' } });
}

