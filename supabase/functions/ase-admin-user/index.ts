import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' }
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  const url = Deno.env.get('SUPABASE_URL')!, anon = Deno.env.get('SUPABASE_ANON_KEY')!, secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const authHeader = req.headers.get('Authorization') || ''
  const caller = createClient(url, anon, { global: { headers: { Authorization: authHeader } } })
  const token = authHeader.replace(/^Bearer\s+/i, '')
  const { data: { user }, error: authError } = await caller.auth.getUser(token)
  if (authError || !user) return json({ error: 'Unauthorized' }, 401)
  const { data: actor } = await caller.from('ase_profiles').select('role,status').eq('id', user.id).maybeSingle()
  if (actor?.role !== 'admin' || actor?.status !== 'active') return json({ error: 'Forbidden' }, 403)
  const admin = createClient(url, secret, { auth: { autoRefreshToken: false, persistSession: false } })
  let body: { action?: string; id?: string; email?: string; name?: string; role?: string }
  try { body = await req.json() } catch { return json({ error: 'Invalid JSON' }, 400) }
  if (body.action === 'invite') {
    if (!body.email || !body.name || !['Joueur','Club','Académie','Scout','Agent','Média','Investisseur'].includes(body.role || '')) return json({ error: 'Missing or invalid invite fields' }, 400)
    const { data, error } = await admin.auth.admin.inviteUserByEmail(body.email, { data: { display_name: body.name, requested_role: body.role } })
    return error ? json({ error: error.message }, 400) : json({ id: data.user.id })
  }
  if (body.action === 'delete' && body.id) {
    const { error } = await admin.auth.admin.deleteUser(body.id)
    return error ? json({ error: error.message }, 400) : json({ ok: true })
  }
  return json({ error: 'Unsupported action' }, 400)
})
