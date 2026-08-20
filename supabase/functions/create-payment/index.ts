/// <reference path="../global.d.ts" />
import Razorpay from "npm:razorpay@2.9.6";
import { createClient } from "jsr:@supabase/supabase-js@2";
import supabaseAdmin from "../_shared/supabaseAdmin.ts";
import { corsHeaders } from "../_shared/cors.ts";

const razorpayKeyId = Deno.env.get('RAZORPAY_KEY_ID');
const razorpayKeySecret = Deno.env.get('RAZORPAY_KEY_SECRET');

const jsonResponse = (body: Record<string, unknown>, status = 200) => new Response(
  JSON.stringify(body),
  { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
);

Deno.serve(async (req: Request) => {

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authorization = req.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) {
      console.error('Authentication failed: Missing authorization header');
      return new Response(JSON.stringify({ error: 'Unauthorized: Missing authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    // Use a caller-scoped client to authenticate the request. The service-role
    // client below is intentionally used only after the caller is identified.
    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authorization } } },
    );
    const { data: { user }, error: userError } = await callerClient.auth.getUser();
    if (userError || !user) {
      console.error('Auth Error:', userError);
      return new Response(JSON.stringify({ error: 'Unauthorized: Invalid token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const userId: string = user.id;

    const requestBody = await req.json();
    const { plan_id, plan_type = 'visit', property_id, custom_amount } = requestBody;
    console.log(`[create-payment] Received plan_id: ${plan_id}, plan_type: ${plan_type}, custom_amount: ${custom_amount}`);

    if (!razorpayKeyId || !razorpayKeySecret) {
      console.error('Razorpay credentials are not configured.');
      return jsonResponse({ error: 'Payment gateway is not configured. Please contact support.' }, 500);
    }
    if (!razorpayKeyId.startsWith('rzp_')) {
      console.error('RAZORPAY_KEY_ID has an invalid format.');
      return jsonResponse({ error: 'Payment gateway credentials are invalid. Please contact support.' }, 500);
    }
    const razorpay = new Razorpay({ key_id: razorpayKeyId, key_secret: razorpayKeySecret });
    if (!plan_id) {
      console.error('Missing plan_id in request');
      return new Response(JSON.stringify({ error: 'Missing plan_id in request body' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (plan_type === 'property_management') {
      if (!property_id) {
        return new Response(JSON.stringify({ error: 'Missing property_id for management payment.' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      const { data: property, error: propertyError } = await (supabaseAdmin as any)
        .from('properties')
        .select('property_id, submitter, management_plan_id, admin_status, listing_type')
        .eq('property_id', property_id)
        .maybeSingle();
      if (propertyError || !property || property.submitter !== userId) {
        return new Response(JSON.stringify({ error: 'Pending property was not found or does not belong to you.' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }
      if (property.management_plan_id !== plan_id) {
        return new Response(JSON.stringify({ error: 'The selected plan does not match the pending property.' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }
      if (property.listing_type !== 'RENTAL') {
        return new Response(JSON.stringify({ error: 'Management plans are available only for rental properties.' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      const { data: managementPlan, error: managementPlanError } = await (supabaseAdmin as any)
        .from('management_service_plans')
        .select('plan_id, is_active, post_price, document_processing_fee_enabled')
        .eq('plan_id', plan_id)
        .maybeSingle();
      if (managementPlanError || !managementPlan?.is_active) {
        return new Response(JSON.stringify({ error: 'Selected management plan is not active.' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      const { data: paidPayment } = await (supabaseAdmin as any)
        .from('transactions')
        .select('transaction_id')
        .eq('property_id', property_id)
        .eq('payment_type', 'property_management')
        .eq('status', 'paid')
        .maybeSingle();
      if (paidPayment) {
        return new Response(JSON.stringify({ error: 'This property has already been paid for.' }), { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      // The listing-fee decision is intentionally made here, never in the browser.
      const { data: customer } = await (supabaseAdmin as any).from('customers').select('listing_quota').eq('user_id', userId).maybeSingle();
      const { data: paidTransactions } = await (supabaseAdmin as any)
        .from('transactions').select('payment_type, amount')
        .eq('user_id', userId).eq('status', 'paid').in('payment_type', ['property_listing', 'property_management']);
      const paidListingCredits = (paidTransactions ?? []).filter((payment: { payment_type: string; amount: number }) =>
        payment.payment_type === 'property_listing' || Number(payment.amount) >= 1099
      ).length;
      const { count: existingPropertyCount } = await (supabaseAdmin as any)
        .from('properties').select('property_id', { count: 'exact', head: true })
        .eq('submitter', userId).neq('property_id', property_id).neq('admin_status', 'PAYMENT_PENDING');
      const allowedQuota = (customer?.listing_quota ?? 1) + paidListingCredits;
      const listingFee = (existingPropertyCount ?? 0) >= allowedQuota ? 99 : 0;
      // A plan price is collectible only when the admin explicitly enables the
      // document-processing charge for that plan.
      const documentProcessingFee = managementPlan.document_processing_fee_enabled
        ? Number(managementPlan.post_price)
        : 0;
      const amount = documentProcessingFee + listingFee;

      const receipt = `MP_${property_id.substring(0, 8)}_${Date.now().toString().slice(-8)}`;
      const order = await razorpay.orders.create({ amount: amount * 100, currency: 'INR', receipt, notes: { customer_id: userId, property_id, plan_id, plan_type } });
      const { data: transaction, error: transactionError } = await (supabaseAdmin as any)
        .from('transactions')
        .insert({ user_id: userId, property_id, management_plan_id: plan_id, amount, razorpay_order_id: order.id, status: 'created', payment_type: 'property_management' })
        .select('transaction_id')
        .single();
      if (transactionError) throw new Error('Failed to record management payment attempt.');

      await (supabaseAdmin as any).from('properties').update({ admin_status: 'PAYMENT_PENDING', is_listed: false }).eq('property_id', property_id).eq('submitter', userId);
      return new Response(JSON.stringify({ orderId: order.id, amount: order.amount, transactionId: transaction.transaction_id, keyId: razorpayKeyId }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    let plansData: { plan_id: string; name: string; price: number; is_active: boolean } | null = null;
    let planError;

    if (plan_type === 'contact') {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const { data, error } = await (supabaseAdmin as any)
        .from('contact_plans')
        .select('plan_id, name, price, is_active')
        .eq('plan_id', plan_id)
        .maybeSingle();
      plansData = data;
      planError = error;
    } else {
      const { data, error } = await supabaseAdmin
        .from('visit_plans')
        .select('plan_id, name, price, is_active')
        .eq('plan_id', plan_id)
        .maybeSingle();
      plansData = data;
      planError = error;
    }

    if (planError) {
      console.error('Error fetching plan:', planError);
      throw new Error('Could not retrieve plan details.');
    }
    if (!plansData) {
      console.error(`Plan not found: ${plan_id}`);
      return new Response(JSON.stringify({ error: `Plan not found: ${plan_id}` }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (!plansData.is_active) {
      console.error(`Plan ${plan_id} is not active`);
      return new Response(JSON.stringify({ error: 'Selected plan is not active.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const isPropertyListingPlan = plan_type === 'property_listing' || (plansData && plansData.name.toLowerCase().includes('listing'));
    const selectedPlanPrice = isPropertyListingPlan 
      ? (typeof custom_amount === 'number' && custom_amount > 0 ? custom_amount : (plansData.price || 99)) 
      : plansData.price;

    const timestamp = Date.now().toString().slice(-8);
    const receipt = `P${plan_id.substring(0, 6)}_U${userId.substring(0, 6)}_${timestamp}`;

    const orderOptions = {
      amount: Math.round(selectedPlanPrice * 100),
      currency: 'INR',
      receipt: receipt,
      notes: {
        customer_id: userId,
        plan_id: plan_id,
        plan_type: plan_type
      }
    };

    const order = await razorpay.orders.create(orderOptions);

    const transactionData: any = {
      user_id: userId,
      amount: selectedPlanPrice,
      razorpay_order_id: order.id,
      status: 'created'
    };

    if (plan_type === 'contact') {
      transactionData.contact_plan_id = plan_id;
    } else {
      transactionData.plan_id = plan_id;
    }

    const { data: transactionInsertData, error: transactionError } = await supabaseAdmin
      .from('transactions')
      .insert(transactionData)
      .select('transaction_id')
      .single();

    if (transactionError) {
      console.error('Error inserting transaction:', transactionError);
      throw new Error('Failed to record transaction.');
    }

    const transactionId = transactionInsertData.transaction_id;
    console.log(`Transaction recorded with ID: ${transactionId} for user ${userId} with plan ${plan_id}`);

    const responseData = {
      orderId: order.id,
      amount: order.amount,
      transactionId: transactionId,
      keyId: razorpayKeyId
    };

    return new Response(
      JSON.stringify(responseData),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );

  } catch (error: any) {
    console.error('Error creating payment:', error);
    console.error('Error stack:', error.stack);
    if (error.error) {
      console.error('Razorpay error details:', error.error);
    }
    const isRazorpayAuthenticationFailure = error?.error?.description === 'Authentication failed';
    const errorMessage = isRazorpayAuthenticationFailure
      ? 'Payment gateway authentication failed. Please contact support.'
      : error.message || (error.error?.description) || 'Failed to create payment';
    console.error(`Returning error response: ${errorMessage}`);
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: error.statusCode || 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
