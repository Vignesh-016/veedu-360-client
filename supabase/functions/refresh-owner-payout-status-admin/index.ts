/// <reference path="../global.d.ts" />
import supabaseAdmin from '../_shared/supabaseAdmin.ts';
import { getRazorpayCredentials } from '../_shared/razorpayCredentials.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,x-client-info',
  'Access-Control-Allow-Methods': 'OPTIONS,POST',
};

const out = (body: Record<string, unknown>, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: {
    ...corsHeaders,
    'Content-Type': 'application/json'
  }
});

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return out({ error: 'Method not allowed' }, 405);
  }

  const auth = req.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) {
    return out({ error: 'Unauthorized' }, 401);
  }

  const { data: { user }, error } = await supabaseAdmin.auth.getUser(auth.slice(7));
  if (error || !user) {
    return out({ error: 'Unauthorized' }, 401);
  }

  // Authorization: Only super-admin or accounts-team can trigger this
  const { data: admin } = await (supabaseAdmin as any)
    .from('admins')
    .select('roles')
    .eq('user_id', user.id)
    .maybeSingle();

  const hasAccess =
    admin?.roles?.some((r: string) => ['super-admin', 'accounts-team'].includes(r));

  if (!hasAccess) {
    return out({ error: 'Forbidden: Insufficient permissions' }, 403);
  }

  const { owner_user_id, payout_account_id } = await req.json().catch(() => ({}));
  if (typeof owner_user_id !== 'string') {
    return out({ error: 'owner_user_id is required' }, 400);
  }

  let payoutQuery = (supabaseAdmin as any)
    .from('owner_payout_accounts')
    .select('payout_account_id,razorpay_account_id,razorpay_product_id')
    .eq('owner_user_id', owner_user_id);
  if (typeof payout_account_id === 'string' && payout_account_id) {
    payoutQuery = payoutQuery.eq('payout_account_id', payout_account_id);
  } else {
    payoutQuery = payoutQuery
      .order('payment_eligible', { ascending: false })
      .order('created_at', { ascending: true });
  }
  const { data: payout } = await payoutQuery.limit(1).maybeSingle();

  if (!payout?.razorpay_account_id || !payout?.razorpay_product_id) {
    return out({ error: 'Payout account not ready for status sync' }, 400);
  }

  const { keyId, keySecret } = getRazorpayCredentials();
  if (!keyId || !keySecret) {
    return out({ error: 'Razorpay is not configured' }, 500);
  }

  const headers = {
    Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}`
  };

  try {
    // Fetch account details
    const accountRes = await fetch(
      `https://api.razorpay.com/v2/accounts/${payout.razorpay_account_id}`,
      { headers }
    );

    // Fetch product status
    const productRes = await fetch(
      `https://api.razorpay.com/v2/accounts/${payout.razorpay_account_id}/products/${payout.razorpay_product_id}`,
      { headers }
    );

    const account = await accountRes.json().catch(() => ({}));
    const product = await productRes.json().catch(() => ({}));

    if (!accountRes.ok || !productRes.ok) {
      return out({ error: 'Razorpay status lookup failed' }, 502);
    }

    const productStatus = (product.activation_status || product.status || 'requested').toLowerCase();
    const accountStatus = (account.status || 'requested').toLowerCase();
    const requirements = Array.isArray(product.requirements)
      ? product.requirements.map((requirement: any) => ({
          field: String(requirement?.field_reference || requirement?.field || 'unknown'),
          status: String(requirement?.status || requirement?.reason_code || 'pending'),
        }))
      : [];

    const eligible = accountStatus === 'activated' && productStatus === 'activated';

    const { error: updateError } = await (supabaseAdmin as any)
      .from('owner_payout_accounts')
      .update({
        razorpay_account_status: accountStatus,
        razorpay_product_status: productStatus,
        payment_eligible: eligible,
        status: eligible ? 'VERIFIED' : productStatus === 'needs_clarification' ? 'ACTION_REQUIRED' : productStatus === 'verification_failed' ? 'VERIFICATION_FAILED' : productStatus === 'suspended' ? 'SUSPENDED' : 'PENDING_VERIFICATION',
        route_onboarding_error: null,
        last_status_checked_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('payout_account_id', payout.payout_account_id);
    if (updateError) {
      console.error('[refresh-owner-payout-status-admin] Status persistence failed.', {
        payout_account_id: payout.payout_account_id,
        code: updateError.code,
        message: updateError.message,
      });
      return out({ error: 'Razorpay status was fetched but could not be saved' }, 500);
    }

    return out({
      status: eligible ? 'Verified' : 'Verification In Progress',
      payment_eligible: eligible,
      razorpay_account_status: accountStatus,
      razorpay_product_status: productStatus,
      requirements,
      payout_account_id: payout.payout_account_id,
    });

  } catch (err) {
    console.error('[refresh-owner-payout-status-admin] Error:', err);
    return out({ error: 'Internal server error during status refresh' }, 500);
  }
});
