/// <reference path="../global.d.ts" />
import crypto from 'node:crypto';
import supabaseAdmin from '../_shared/supabaseAdmin.ts';

const razorpayWebhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET');

const response = (body: Record<string, unknown>, status = 200) => new Response(
  JSON.stringify(body),
  { status, headers: { 'Content-Type': 'application/json' } },
);

const hasValidSignature = (body: string, signature: string, secret: string) => {
  const expected = crypto.createHmac('sha256', secret).update(body).digest('hex');
  const receivedBytes = new TextEncoder().encode(signature);
  const expectedBytes = new TextEncoder().encode(expected);

  return receivedBytes.length === expectedBytes.length
    && crypto.timingSafeEqual(receivedBytes, expectedBytes);
};

const completePaidTransaction = async (
  transaction: { transaction_id: string; status: string; payment_type: string | null },
  orderId: string,
  paymentId: string,
) => {
  if (transaction.status !== 'paid') {
    const { error } = await supabaseAdmin.rpc('update_transaction_status', {
      p_razorpay_order_id: orderId,
      p_status: 'paid',
      p_razorpay_payment_id: paymentId,
    });
    if (error) throw new Error(`Could not mark transaction paid: ${error.message}`);
  }

  // Both RPCs are idempotent. Always invoke completion: a previous delivery can
  // have persisted the paid status but failed before publishing the property or
  // granting the purchased credits.
  const rpc = transaction.payment_type === 'property_management'
    ? 'complete_property_management_payment'
    : 'complete_purchase';
  const args = transaction.payment_type === 'property_management'
    ? {
        p_razorpay_order_id: orderId,
        p_razorpay_payment_id: paymentId,
      }
    : { p_razorpay_order_id: orderId };
  const { error } = await (supabaseAdmin as any).rpc(rpc, args);
  if (error) throw new Error(`Could not complete transaction: ${error.message}`);
};

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return response({ error: 'Method not allowed' }, 405);
  }
  if (!razorpayWebhookSecret) {
    console.error('RAZORPAY_WEBHOOK_SECRET is not configured.');
    return response({ error: 'Webhook is not configured' }, 500);
  }

  const signature = req.headers.get('x-razorpay-signature');
  if (!signature) {
    return response({ error: 'Missing Razorpay signature' }, 401);
  }

  let rawBody: string;
  try {
    rawBody = await req.text();
  } catch (error) {
    console.error('Unable to read Razorpay webhook body:', error);
    return response({ error: 'Invalid request body' }, 400);
  }

  try {
    if (!hasValidSignature(rawBody, signature, razorpayWebhookSecret)) {
      console.error('Rejected Razorpay webhook with an invalid signature.');
      return response({ error: 'Invalid Razorpay signature' }, 401);
    }
  } catch (error) {
    console.error('Unable to validate Razorpay webhook signature:', error);
    return response({ error: 'Signature verification failed' }, 500);
  }

  let event: any;
  try {
    event = JSON.parse(rawBody);
  } catch {
    return response({ error: 'Malformed JSON payload' }, 400);
  }

  try {
    if (event.event === 'order.paid') {
      const order = event.payload?.order?.entity;
      const payment = event.payload?.payment?.entity;
      const orderId = order?.id;
      const paymentId = payment?.id;

      if (!orderId || !paymentId || order.currency !== 'INR') {
        console.error('Malformed order.paid event.', { orderId, paymentId, currency: order?.currency });
        return response({ error: 'Malformed order.paid event' }, 400);
      }

      const { data: transaction, error: lookupError } = await (supabaseAdmin as any)
        .from('transactions')
        .select('transaction_id, status, payment_type, amount')
        .eq('razorpay_order_id', orderId)
        .maybeSingle();
      if (lookupError) throw new Error(`Could not load transaction: ${lookupError.message}`);
      if (!transaction) {
        // A 5xx tells Razorpay to retry. This protects against a webhook arriving
        // while a payment-order transaction is still being persisted.
        throw new Error(`No transaction exists for Razorpay order ${orderId}`);
      }
      if (Number(order.amount) !== Math.round(Number(transaction.amount) * 100)) {
        throw new Error(`Amount mismatch for order ${orderId}`);
      }

      await completePaidTransaction(transaction, orderId, paymentId);
      console.log(`Processed Razorpay order.paid for transaction ${transaction.transaction_id}.`);
      return response({ received: true });
    }

    if (event.event === 'payment.failed') {
      const payment = event.payload?.payment?.entity;
      const orderId = payment?.order_id;
      if (!orderId) {
        return response({ error: 'Malformed payment.failed event' }, 400);
      }

      const { data: transaction, error: lookupError } = await (supabaseAdmin as any)
        .from('transactions')
        .select('transaction_id, status')
        .eq('razorpay_order_id', orderId)
        .maybeSingle();
      if (lookupError) throw new Error(`Could not load transaction: ${lookupError.message}`);
      if (!transaction) {
        console.warn(`No transaction exists for failed Razorpay order ${orderId}.`);
        return response({ received: true });
      }
      if (transaction.status === 'paid') {
        console.warn(`Ignoring payment.failed for already-paid transaction ${transaction.transaction_id}.`);
        return response({ received: true });
      }

      const errorMessage = [payment.error_code, payment.error_description]
        .filter(Boolean)
        .join(': ') || 'Payment failed at Razorpay.';
      const { error } = await supabaseAdmin.rpc('update_transaction_status', {
        p_razorpay_order_id: orderId,
        p_status: 'failed',
        p_razorpay_payment_id: payment.id ?? undefined,
        p_error_message: errorMessage,
      });
      if (error) throw new Error(`Could not mark failed transaction: ${error.message}`);

      // Keep the pending property. The customer can safely create a new payment
      // attempt instead of losing their completed property form and images.
      console.log(`Recorded Razorpay payment failure for transaction ${transaction.transaction_id}.`);
      return response({ received: true });
    }

    console.log(`Ignoring unsupported Razorpay event: ${event.event ?? 'unknown'}.`);
    return response({ received: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unexpected webhook processing error';
    console.error('Razorpay webhook processing failed:', message);
    // Razorpay retries non-2xx responses, allowing transient database failures
    // to be reconciled without trusting the browser callback.
    return response({ error: 'Webhook processing failed' }, 500);
  }
});
