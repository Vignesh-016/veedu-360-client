import supabaseAdmin from '../_shared/supabaseAdmin.ts';
import { getRazorpayCredentials } from '../_shared/razorpayCredentials.ts';
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization,apikey,content-type,x-client-info', 'Access-Control-Allow-Methods': 'POST,OPTIONS' };
const out = (body: Record<string, unknown>, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (req.method !== 'POST') return out({ success: false, code: 'METHOD_NOT_ALLOWED', message: 'Method not allowed.' }, 405);
  const auth = req.headers.get('Authorization'); if (!auth?.startsWith('Bearer ')) return out({ success: false, code: 'UNAUTHORIZED', message: 'Authentication required.' }, 401);
  const { data: { user } } = await supabaseAdmin.auth.getUser(auth.slice(7)); if (!user) return out({ success: false, code: 'UNAUTHORIZED', message: 'Authentication required.' }, 401);
  const { data: admin } = await (supabaseAdmin as any).from('admins').select('roles').eq('user_id', user.id).maybeSingle(); if (!admin?.roles?.some((r: string) => ['super-admin', 'accounts-team'].includes(r))) return out({ success: false, code: 'FORBIDDEN', message: 'You are not authorised to create rent records.' }, 403);
  const body = await req.json().catch(() => ({})); const { p_property_id, p_due_date, p_period_start_date, p_period_end_date, p_amount_due, p_notes, p_owner_payout_override, p_override_reason } = body;
  if (!p_property_id) return out({ success: false, code: 'PROPERTY_REQUIRED', message: 'Property is required.' }, 400);
  const { data: property } = await (supabaseAdmin as any).from('properties').select('submitter,management_plan_id,management_service_plans(requires_payout_account)').eq('property_id', p_property_id).maybeSingle();
  if (!property?.submitter) return out({ success: false, code: 'OWNER_NOT_FOUND', message: 'Property owner not found.' }, 409);
  const requiresPayout = Boolean(property.management_service_plans?.requires_payout_account);
  if (requiresPayout) {
    const { data: payout } = await (supabaseAdmin as any).from('owner_payout_accounts').select('razorpay_account_id,razorpay_product_id,razorpay_product_status,payment_eligible').eq('owner_user_id', property.submitter).maybeSingle();
    if (!payout) return out({ success: false, code: 'OWNER_PAYOUT_NOT_CONFIGURED', message: 'The property owner has not completed payout setup yet.' }, 409);
    if (!payout.razorpay_account_id || !payout.razorpay_product_id) return out({ success: false, code: 'OWNER_PAYOUT_NOT_CONFIGURED', message: 'The property owner has not completed payout setup yet.' }, 409);
    const { keyId, keySecret } = getRazorpayCredentials(); if (!keyId || !keySecret) return out({ success: false, code: 'RAZORPAY_NOT_CONFIGURED', message: 'Payout status could not be checked.' }, 500);
    const headers = { Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}` };
    const [accountResponse, productResponse] = await Promise.all([fetch(`https://api.razorpay.com/v2/accounts/${payout.razorpay_account_id}`, { headers }), fetch(`https://api.razorpay.com/v2/accounts/${payout.razorpay_account_id}/products/${payout.razorpay_product_id}`, { headers })]);
    const account = await accountResponse.json().catch(() => ({})); const product = await productResponse.json().catch(() => ({}));
    if (!accountResponse.ok || !productResponse.ok) return out({ success: false, code: 'PAYOUT_STATUS_UNAVAILABLE', message: 'Payout status could not be checked.' }, 502);
    const productStatus = String(product.activation_status || product.status || 'requested').toLowerCase(); const eligible = productStatus === 'activated';
    const { error: syncError } = await (supabaseAdmin as any).from('owner_payout_accounts').update({ razorpay_account_status: account.status || null, razorpay_product_status: productStatus, payment_eligible: eligible, status: eligible ? 'VERIFIED' : 'PENDING_VERIFICATION', last_status_checked_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq('owner_user_id', property.submitter);
    if (syncError) return out({ success: false, code: 'PAYOUT_STATUS_SYNC_FAILED', message: 'Payout status could not be synchronized.' }, 500);
    if (!eligible) return out({ success: false, code: productStatus === 'needs_clarification' ? 'OWNER_PAYOUT_ACTION_REQUIRED' : 'OWNER_PAYOUT_PENDING', message: productStatus === 'needs_clarification' ? 'The property owner\'s payout account requires additional verification.' : 'The property owner\'s payout verification is still pending.' }, 409);
  }
  const { data: rent, error } = await (supabaseAdmin as any).rpc('create_rent_record_admin', { p_property_id, p_due_date, p_period_start_date, p_period_end_date, p_amount_due, p_notes: p_notes ?? null, p_owner_payout_override: p_owner_payout_override ?? null, p_override_reason: p_override_reason ?? null });
  if (error) { const message = String(error.message || ''); const code = message.startsWith('OWNER_PAYOUT_NOT_ELIGIBLE') ? 'OWNER_PAYOUT_NOT_ELIGIBLE' : 'RENT_RECORD_NOT_CREATED'; return out({ success: false, code, message: code === 'OWNER_PAYOUT_NOT_ELIGIBLE' ? 'The property owner is not yet eligible to receive rent payouts.' : message }, 409); }
  return out({ success: true, rent_record_created: true, rent_record_id: rent });
});
