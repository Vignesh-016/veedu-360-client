import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import crypto from 'node:crypto';
import supabaseAdmin from '../_shared/supabaseAdmin.ts';

const razorpayWebhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET');

if (!razorpayWebhookSecret) {
  console.error("Razorpay Webhook Secret is not configured. Webhook cannot be verified.");
  // This is a critical configuration. The function should ideally not proceed without it.
}

Deno.serve(async (req) => {
  if (!razorpayWebhookSecret) {
    // Return 500 if secret is not set, as webhook verification is impossible
    return new Response('Webhook secret not configured on server', { status: 500 });
  }

  const rawBody = await req.text();
  const signature = req.headers.get('x-razorpay-signature');

  if (!signature) {
    console.warn('Webhook Warning: Missing x-razorpay-signature header. Request will be ignored.');
    return new Response('Signature required', { status: 401 }); // Unauthorized
  }

  try {
    const isValid = crypto
      .createHmac('sha256', razorpayWebhookSecret)
      .update(rawBody)
      .digest('hex') === signature;

    if (!isValid) {
      console.error('Webhook Error: Invalid Razorpay signature.');
      return new Response('Invalid signature', { status: 400 }); // Bad request
    }
  } catch (error: any) {
    console.error('Webhook Error during signature verification:', error.message);
    return new Response('Signature verification failed', { status: 500 });
  }

  try {
    const event = JSON.parse(rawBody);

    // Primary focus: 'order.paid'
    if (event.event === 'order.paid') {
      const orderEntity = event.payload.order?.entity;
      const paymentEntity = event.payload.payment?.entity;

      if (!orderEntity || !paymentEntity) {
        console.error('Webhook Error: order.paid event missing order or payment entity in payload.');
        return new Response('Malformed order.paid event payload', { status: 400 });
      }

      const orderId = orderEntity.id;
      const paymentId = paymentEntity.id;
      // The signature here is from the payment entity, which might be useful for auditing if stored
      // but the webhook's own signature (x-razorpay-signature) is what authenticates the webhook itself.
      const paymentSignature = paymentEntity.signature;

      console.log(`Processing order.paid event via webhook for Razorpay Order ID: ${orderId}`);

      const { data: transaction, error: transactionError } = await supabaseAdmin
        .from('transactions')
        .select('transaction_id, status, user_id, plan_id, amount') // Fetch necessary fields
        .eq('razorpay_order_id', orderId)
        .maybeSingle();

      if (transactionError) {
        console.error(`Webhook Error: DB error finding transaction for order ${orderId}:`, transactionError.message);
        return new Response('Database error finding transaction', { status: 500 }); // Server error, Razorpay might retry
      }

      if (!transaction) {
        console.error(`Webhook Critical: Transaction not found in DB for paid Razorpay order ID: ${orderId}. This payment might be orphaned.`);
        // Acknowledge to Razorpay to stop retries for this specific event, but this needs investigation.
        return new Response('Transaction not found by order ID', { status: 200 });
      }

      if (transaction.status !== 'paid') {
        console.log(`Transaction ${transaction.transaction_id} (Order ${orderId}) is not yet 'paid'. Updating via webhook...`);

        // Using the presumed service-role `update_transaction_status` RPC
        const { error: updateError } = await supabaseAdmin.rpc('update_transaction_status', {
          p_razorpay_order_id: orderId,
          p_status: 'paid',
          p_razorpay_payment_id: paymentId,
          p_razorpay_signature: paymentSignature, // Store the payment signature for reference
          p_error_message: null // Clear any previous errors
        });

        if (updateError) {
          console.error(`Webhook Error: Failed to update transaction ${transaction.transaction_id} status to 'paid':`, updateError.message);
          return new Response('Error updating transaction status', { status: 500 }); // Server error, Razorpay might retry
        }

        // Using the presumed service-role `complete_purchase` RPC
        const { error: completeError } = await supabaseAdmin.rpc('complete_purchase', {
          p_razorpay_order_id: orderId,
        });

        if (completeError) {
          console.error(`Webhook Error: Failed to complete purchase for transaction ${transaction.transaction_id} (Order ${orderId}):`, completeError.message);
          // Transaction is paid, but visits not added. Critical to investigate.
          return new Response('Error completing purchase actions', { status: 500 }); // Server error, Razorpay might retry
        }
        console.log(`Webhook: Successfully processed order.paid for transaction ${transaction.transaction_id}.`);
      } else {
        console.log(`Webhook: Transaction ${transaction.transaction_id} (Order ${orderId}) already 'paid'. Idempotent handling, no action taken.`);
      }
    } else if (event.event === 'payment.failed') {
      const orderId = event.payload.payment?.entity?.order_id;
      const paymentId = event.payload.payment?.entity?.id;
      const errorCode = event.payload.payment?.entity?.error_code;
      const errorDescription = event.payload.payment?.entity?.error_description;

      if (orderId) {
        console.log(`Processing payment.failed event via webhook for Razorpay Order ID: ${orderId}`);
        const { error: updateFailedError } = await supabaseAdmin.rpc('update_transaction_status', {
          p_razorpay_order_id: orderId,
          p_status: 'failed',
          p_razorpay_payment_id: paymentId || null,
          p_razorpay_signature: null, // No signature to store for failed payment typically
          p_error_message: `Payment failed: ${errorCode} - ${errorDescription}`
        });
        if (updateFailedError) {
          console.error(`Webhook Error: Failed to update transaction status to 'failed' for order ${orderId}:`, updateFailedError.message);
          // Don't necessarily return 500, as this is an informational update.
        } else {
          console.log(`Webhook: Transaction for order ${orderId} updated to 'failed'.`);
        }
      } else {
        console.warn('Webhook: payment.failed event received without an order_id. Cannot update transaction.');
      }
    }
    else {
      console.log(`Webhook Event Received: ${event.event}. No specific action configured for this event beyond logging.`);
    }

    return new Response('Webhook processed', { status: 200 });

  } catch (error: any) {
    console.error('Webhook general processing error:', error.message);
    console.error('Webhook error stack:', error.stack);
    return new Response('Internal Server Error during webhook processing', { status: 500 });
  }
});