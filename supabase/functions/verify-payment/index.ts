import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import crypto from 'node:crypto';
import supabaseAdmin from "../_shared/supabaseAdmin.ts";
import { corsHeaders } from "../_shared/cors.ts";

const razorpayKeySecret = Deno.env.get('RAZORPAY_KEY_SECRET');

if (!razorpayKeySecret) {
  console.error("Razorpay Key Secret is not configured.");
  // Consider throwing an error or exiting if this is critical for function startup
}

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
    // Note: User authentication (authHeader) is present but not explicitly used to fetch user details
    // This implies the function trusts the client to send correct Razorpay IDs,
    // and the primary security is the signature check and subsequent actions are on specific order_ids.

    const requestBody = await req.json();
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = requestBody;

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      console.error('Missing required Razorpay parameters:', {
        order_id_missing: !razorpay_order_id,
        payment_id_missing: !razorpay_payment_id,
        signature_missing: !razorpay_signature
      });
      return new Response(JSON.stringify({ error: 'Missing required Razorpay parameters' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const bodyToVerify = `${razorpay_order_id}|${razorpay_payment_id}`;
    const expectedSignature = crypto
      .createHmac('sha256', razorpayKeySecret!)
      .update(bodyToVerify)
      .digest('hex');

    console.log('Signature comparison:', {
      expected: `${expectedSignature.substring(0, 10)}...`,
      received: `${razorpay_signature.substring(0, 10)}...`,
      match: expectedSignature === razorpay_signature
    });

    const isSignatureValid = expectedSignature === razorpay_signature;

    if (!isSignatureValid) {
      console.error('SIGNATURE VALIDATION FAILED for order_id:', razorpay_order_id);
      // Optionally, still update transaction to 'failed' but this function path is for valid signature by client.
      // If the intent is that this EF calls DB function to update status anyway:
      const { error: updateFailedError } = await supabaseAdmin.rpc(
        'update_transaction_status', // Assuming this RPC can handle 'failed' status
        {
          p_razorpay_order_id: razorpay_order_id,
          p_status: 'failed',
          p_razorpay_payment_id: razorpay_payment_id,
          p_razorpay_signature: razorpay_signature, // Store the invalid one for audit
          p_error_message: 'Invalid Razorpay signature received from client verification.'
        }
      );
      if (updateFailedError) {
        console.error('Error updating transaction status to failed after client-side signature mismatch:', updateFailedError);
      }
      return new Response(JSON.stringify({ error: 'Invalid signature' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Signature is valid, proceed to mark as 'paid' and complete purchase.
    // This assumes there's an RPC `update_transaction_status` that takes these parameters.
    // And an RPC `complete_purchase` that takes `razorpay_order_id`.

    console.log(`Signature valid for order ${razorpay_order_id}. Updating transaction to 'paid'.`);
    const { error: updatePaidError } = await supabaseAdmin.rpc(
      'update_transaction_status', // This name implies a generic status update function
      {
        p_razorpay_order_id: razorpay_order_id,
        p_status: 'paid',
        p_razorpay_payment_id: razorpay_payment_id,
        p_razorpay_signature: razorpay_signature,
        p_error_message: null // Clear any previous errors
      }
    );

    if (updatePaidError) {
      console.error('Error updating transaction status to paid via RPC:', updatePaidError);
      throw new Error(`Failed to update transaction status: ${updatePaidError.message}`);
    }
    console.log(`Transaction for order ${razorpay_order_id} updated to 'paid'. Completing purchase.`);

    const { error: completeError } = await supabaseAdmin.rpc(
      'complete_purchase', // This name implies it finalizes based on order_id
      {
        p_razorpay_order_id: razorpay_order_id
      }
    );

    if (completeError) {
      console.error('Error completing purchase via RPC:', completeError);
      // Potentially, the transaction is 'paid' but visits not added. Needs monitoring/reconciliation.
      throw new Error(`Failed to complete purchase after payment: ${completeError.message}`);
    }

    console.log(`Purchase successfully completed for order ${razorpay_order_id}!`);

    return new Response(JSON.stringify({ success: true, message: "Payment verified and purchase completed." }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error: any) {
    console.error('Error verifying payment:', error.message);
    console.error('Error stack:', error.stack);
    return new Response(JSON.stringify({ error: error.message || 'Failed to verify payment' }), {
      status: 500, // Use 500 for unexpected server-side errors
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});