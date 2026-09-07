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

  const { owner_user_id } = await req.json().catch(() => ({}));
  if (typeof owner_user_id !== 'string') {
    return out({ error: 'owner_user_id is required' }, 400);
  }

  const { data: payout } = await (supabaseAdmin as any)
    .from('owner_payout_accounts')
    .select('razorpay_account_id,razorpay_product_id')
    .eq('owner_user_id', owner_user_id)
    .maybeSingle();

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

    const eligible = productStatus === 'activated';

    await (supabaseAdmin as any)
      .from('owner_payout_accounts')
      .update({
        razorpay_account_status: accountStatus,
        razorpay_product_status: productStatus,
        payment_eligible: eligible,
        status: 'PENDING_VERIFICATION',
        last_status_checked_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('owner_user_id', owner_user_id);

    return out({
      status: eligible ? 'Verified' : 'Verification In Progress',
      payment_eligible: eligible,
      razorpay_product_status: productStatus
    });

  } catch (err) {
    console.error('[refresh-owner-payout-status-admin] Error:', err);
    return out({ error: 'Internal server error during status refresh' }, 500);
  }
});
