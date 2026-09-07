import supabaseAdmin from '../_shared/supabaseAdmin.ts';
import { getRazorpayCredentials } from '../_shared/razorpayCredentials.ts';

const json = (body: Record<string, unknown>, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const auth = req.headers.get('Authorization') ?? '';
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  let allowed = service && auth === `Bearer ${service}`;
  if (!allowed && auth.startsWith('Bearer ')) {
    const { data: { user } } = await supabaseAdmin.auth.getUser(auth.slice(7));
    if (user) {
      const { data } = await (supabaseAdmin as any).from('admins').select('user_id').eq('user_id', user.id).maybeSingle();
      allowed = !!data;
    }
  }
  if (!allowed) return json({ error: 'Unauthorized' }, 401);
  const credentials = getRazorpayCredentials();
  if (credentials.mode === 'test') return json({ success: true, status: 'SIMULATED', test_mode: true });
  const { rent_record_id } = await req.json().catch(() => ({}));
  if (typeof rent_record_id !== 'string') return json({ error: 'rent_record_id is required' }, 400);
  const { data: rows, error: claimError } = await supabaseAdmin.rpc('claim_rent_route_transfer', { p_rent_record_id: rent_record_id });
  if (claimError) return json({ error: claimError.message }, 409);
  const transfer = rows?.[0];
  if (!transfer) return json({ error: 'Transfer unavailable' }, 409);
  if (transfer.status === 'PROCESSED' || transfer.status === 'PROCESSING' && transfer.attempt_count > 1) return json({ success: true, status: transfer.status });
  const { keyId, keySecret } = credentials;
  if (!keyId || !keySecret) return json({ error: 'Razorpay credentials unavailable' }, 500);
  const endpoint = `https://api.razorpay.com/v1/payments/${encodeURIComponent(transfer.razorpay_payment_id)}/transfers`;
  try {
    const response = await fetch(endpoint, { method: 'POST', headers: { Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ transfers: [{ account: transfer.razorpay_account_id, amount: transfer.owner_share_paise, currency: 'INR' }] }) });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(`Razorpay transfer failed (${response.status})`);
    const item = body.items?.[0] ?? body.transfer ?? body;
    const state = String(item.transfer_status ?? item.status ?? 'pending').toLowerCase();
    const status = state === 'processed' ? 'PROCESSED' : state === 'failed' ? 'FAILED' : 'PROCESSING';
    await (supabaseAdmin as any).from('route_transfers').update({ razorpay_transfer_id: item.id ?? null, status, failure_reason: status === 'FAILED' ? 'Razorpay reported transfer failure.' : null, updated_at: new Date().toISOString() }).eq('transfer_id', transfer.transfer_id);
    return json({ success: true, status });
  } catch (error) {
    await (supabaseAdmin as any).from('route_transfers').update({ status: 'FAILED', failure_reason: error instanceof Error ? error.message : 'Transfer request failed.', updated_at: new Date().toISOString() }).eq('transfer_id', transfer.transfer_id);
    return json({ success: false, status: 'FAILED' }, 502);
  }
});
