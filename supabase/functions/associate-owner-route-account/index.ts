/// <reference path="../global.d.ts" />
import supabaseAdmin from '../_shared/supabaseAdmin.ts';
import { getRazorpayCredentials } from '../_shared/razorpayCredentials.ts';

const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization,apikey,content-type,x-client-info', 'Access-Control-Allow-Methods': 'OPTIONS,POST' };
const json = (body: Record<string, unknown>, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...headers, 'Content-Type': 'application/json' } });

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);
  const auth = req.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) return json({ error: 'Authentication required.' }, 401);
  const { data: { user } } = await supabaseAdmin.auth.getUser(auth.slice(7));
  const { data: admin } = user ? await (supabaseAdmin as any).from('admins').select('is_active,roles').eq('user_id', user.id).maybeSingle() : { data: null };
  if (!user || !admin?.is_active || !Array.isArray(admin.roles) || admin.roles.length === 0) return json({ error: 'Admin access required.' }, 403);
  const body = await req.json().catch(() => ({}));
  const ownerUserId = String(body.owner_user_id || '');
  const accountId = String(body.razorpay_account_id || '');
  const productId = String(body.razorpay_product_id || '');
  if (!/^[0-9a-f-]{36}$/i.test(ownerUserId) || !/^acc_[A-Za-z0-9]+$/.test(accountId)) return json({ error: 'Valid owner and Razorpay account are required.' }, 400);
  const { keyId, keySecret } = getRazorpayCredentials();
  if (!keyId || !keySecret) return json({ error: 'Razorpay is not configured.' }, 500);
  const basic = { Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}` };
  const response = await fetch(`https://api.razorpay.com/v2/accounts/${accountId}`, { headers: basic });
  const account = await response.json().catch(() => ({}));
  if (!response.ok || account?.id !== accountId) return json({ error: 'Razorpay account could not be verified.', upstream_status: response.status }, 400);
  const { data: existing } = await (supabaseAdmin as any).from('owner_payout_accounts').select('owner_user_id').eq('razorpay_account_id', accountId).maybeSingle();
  if (existing && existing.owner_user_id !== ownerUserId) return json({ error: 'This Razorpay account is already associated with another owner.' }, 409);
  let productStatus: string | null = null;
  if (productId) {
    const productResponse = await fetch(`https://api.razorpay.com/v2/accounts/${accountId}/products/${productId}`, { headers: basic });
    const product = await productResponse.json().catch(() => ({}));
    if (!productResponse.ok) return json({ error: 'Razorpay product could not be verified.', upstream_status: productResponse.status }, 400);
    productStatus = String(product.activation_status || product.status || 'requested').toLowerCase();
  }
  const eligible = productStatus === 'activated';
  const { error } = await (supabaseAdmin as any).from('owner_payout_accounts').update({ razorpay_account_id: accountId, razorpay_account_status: account.status || 'created', ...(productId ? { razorpay_product_id: productId, razorpay_product_status: productStatus } : {}), payment_eligible: eligible, status: eligible ? 'VERIFIED' : 'PENDING_VERIFICATION', route_onboarding_error: null, last_status_checked_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq('owner_user_id', ownerUserId);
  if (error) return json({ error: 'Unable to save the verified Razorpay account association.' }, 500);
  return json({ success: true, account_status: account.status || null, product_status: productStatus, payment_eligible: eligible, associated: true });
});
