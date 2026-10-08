-- Keep the human-readable payout state consistent with Razorpay's persisted
-- activation result for accounts already synchronized before the status fix.
UPDATE public.owner_payout_accounts
SET status = 'VERIFIED', updated_at = NOW()
WHERE payment_eligible IS TRUE
  AND lower(COALESCE(razorpay_product_status, '')) = 'activated';

NOTIFY pgrst, 'reload schema';
