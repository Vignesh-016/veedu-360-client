import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import Razorpay from 'npm:razorpay@2.9.6';
import supabaseAdmin from "../_shared/supabaseAdmin.ts";
import { corsHeaders } from "../_shared/cors.ts";

const razorpayKeyId = Deno.env.get('RAZORPAY_KEY_ID');
const razorpayKeySecret = Deno.env.get('RAZORPAY_KEY_SECRET');

if (!razorpayKeyId || !razorpayKeySecret) {
  console.error("Razorpay API keys are not configured.");
}

const razorpay = new Razorpay({
  key_id: razorpayKeyId!,
  key_secret: razorpayKeySecret!,
});

Deno.serve(async (req) => {

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      console.error('Authentication failed: Missing authorization header');
      return new Response(JSON.stringify({ error: 'Missing authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const token = authHeader.replace('Bearer ', '');

    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !user) {
      console.error('Auth Error:', userError);
      return new Response(JSON.stringify({ error: 'Invalid token or user not found' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const userId: string = user.id;

    const requestBody = await req.json();
    const { plan_id } = requestBody;

    if (!plan_id) {
      console.error('Missing plan_id in request');
      return new Response(JSON.stringify({ error: 'Missing plan_id in request body' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: plansData, error: planError } = await supabaseAdmin
      .from('visit_plans')
      .select('plan_id, price, is_active')
      .eq('plan_id', plan_id)
      .maybeSingle();

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
    const selectedPlanPrice = plansData.price;

    const timestamp = Date.now().toString().slice(-8);
    const receipt = `P${plan_id.substring(0, 6)}_U${userId.substring(0, 6)}_${timestamp}`;

    const orderOptions = {
      amount: Math.round(selectedPlanPrice * 100),
      currency: 'INR',
      receipt: receipt,
      notes: {
        customer_id: userId,
        plan_id: plan_id
      }
    };

    const order = await razorpay.orders.create(orderOptions);

    const transactionData = {
      user_id: userId,
      plan_id: plan_id,
      amount: selectedPlanPrice,
      razorpay_order_id: order.id,
      status: 'created'
    };

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
    const errorMessage = error.message || (error.error?.description) || 'Failed to create payment';
    console.error(`Returning error response: ${errorMessage}`);
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: error.statusCode || 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});