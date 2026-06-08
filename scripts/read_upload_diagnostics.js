const url = 'https://nenugkyvcewatuddrwvf.supabase.co/rest/v1/diagnostics_upload?select=info,created_at&order=created_at.desc&limit=1';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5lbnVna3l2Y2V3YXR1ZGRyd3ZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3NTU1MjIsImV4cCI6MjA3OTMzMTUyMn0.u_pRCCVa41zgUyeQH5rh0R0j2mSONVCxx-7rjmNl9bc';

fetch(url, {
  headers: { 'apikey': anonKey, 'Authorization': `Bearer ${anonKey}` }
})
.then(res => res.json())
.then(data => console.log(JSON.stringify(data[0]?.info, null, 2)))
.catch(err => console.error('Error:', err));
