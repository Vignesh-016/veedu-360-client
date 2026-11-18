-- Repair records where Razorpay/payment finalization succeeded but the rent
-- row or receipt was not persisted. PAID attempts are already gateway-verified.
WITH latest_paid_attempt AS (
  SELECT DISTINCT ON (rent_record_id)
    rent_record_id,
    tenant_user_id,
    amount_paise,
    razorpay_payment_id,
    updated_at
  FROM public.rent_payment_attempts
  WHERE status = 'PAID'
  ORDER BY rent_record_id, updated_at DESC
)
UPDATE public.rent_records rr
SET status = 'PAID',
    amount_paid = latest_paid_attempt.amount_paise::NUMERIC / 100,
    updated_at = NOW()
FROM latest_paid_attempt
WHERE rr.rent_record_id = latest_paid_attempt.rent_record_id
  AND rr.status <> 'CANCELLED';

INSERT INTO public.rent_payments(
  rent_record_id,
  paid_by_user_id,
  amount,
  payment_date,
  payment_method,
  transaction_ref,
  notes
)
SELECT
  a.rent_record_id,
  a.tenant_user_id,
  a.amount_paise::NUMERIC / 100,
  a.updated_at,
  'RAZORPAY',
  a.razorpay_payment_id,
  'Online rent payment'
FROM public.rent_payment_attempts a
JOIN public.rent_records rr ON rr.rent_record_id = a.rent_record_id
WHERE a.status = 'PAID'
  AND a.razorpay_payment_id IS NOT NULL
  AND rr.status <> 'CANCELLED'
  AND NOT EXISTS (
    SELECT 1
    FROM public.rent_payments existing_payment
    WHERE existing_payment.transaction_ref = a.razorpay_payment_id
  );

NOTIFY pgrst, 'reload schema';
