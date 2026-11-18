-- Make rent payment finalization idempotent and repair records that were
-- marked paid before the rent row or receipt was persisted.
CREATE OR REPLACE FUNCTION public.complete_rent_payment(
  p_order_id TEXT,
  p_payment_id TEXT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  a public.rent_payment_attempts%ROWTYPE;
  r public.rent_records%ROWTYPE;
  v_actor UUID := auth.uid();
  v_payment_id TEXT;
  v_amount NUMERIC;
  p public.owner_payout_accounts%ROWTYPE;
BEGIN
  IF p_payment_id IS NULL OR BTRIM(p_payment_id) = '' THEN
    RAISE EXCEPTION 'A captured Razorpay payment ID is required.';
  END IF;

  SELECT * INTO a
  FROM public.rent_payment_attempts
  WHERE razorpay_order_id = p_order_id
  FOR UPDATE;

  IF NOT FOUND OR (v_actor IS NOT NULL AND a.tenant_user_id <> v_actor) THEN
    RAISE EXCEPTION 'Payment attempt not found.';
  END IF;

  SELECT * INTO r
  FROM public.rent_records
  WHERE rent_record_id = a.rent_record_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rent record not found.';
  END IF;
  IF r.status = 'CANCELLED' THEN
    RAISE EXCEPTION 'Rent is cancelled.';
  END IF;
  IF a.status = 'FAILED' THEN
    RAISE EXCEPTION 'Payment attempt is no longer active.';
  END IF;

  v_payment_id := COALESCE(a.razorpay_payment_id, p_payment_id);
  v_amount := a.amount_paise::NUMERIC / 100;

  UPDATE public.rent_payment_attempts
  SET status = 'PAID',
      razorpay_payment_id = COALESCE(razorpay_payment_id, p_payment_id),
      failure_reason = NULL,
      updated_at = NOW()
  WHERE payment_attempt_id = a.payment_attempt_id;

  UPDATE public.rent_records
  SET status = 'PAID',
      amount_paid = v_amount,
      updated_at = NOW()
  WHERE rent_record_id = r.rent_record_id;

  IF v_payment_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.rent_payments
       WHERE transaction_ref = v_payment_id
     ) THEN
    INSERT INTO public.rent_payments(
      rent_record_id, paid_by_user_id, amount, payment_date,
      payment_method, transaction_ref, notes
    )
    VALUES (
      r.rent_record_id, a.tenant_user_id, v_amount, NOW(),
      'RAZORPAY', v_payment_id, 'Online rent payment'
    );
  END IF;

  IF r.payout_account_id IS NOT NULL THEN
    SELECT * INTO p
    FROM public.owner_payout_accounts
    WHERE payout_account_id = r.payout_account_id
      AND owner_user_id = r.landlord_user_id;
  ELSE
    SELECT * INTO p
    FROM public.owner_payout_accounts
    WHERE owner_user_id = r.landlord_user_id
    ORDER BY created_at
    LIMIT 1;
  END IF;

  IF COALESCE(p.payment_eligible, FALSE)
     AND p.razorpay_account_id IS NOT NULL
     AND v_payment_id IS NOT NULL THEN
    INSERT INTO public.route_transfers(
      rent_record_id, payment_attempt_id, razorpay_payment_id,
      owner_user_id, payout_account_id, razorpay_account_id,
      total_amount_paise, owner_share_paise, admin_share_paise
    )
    VALUES (
      r.rent_record_id, a.payment_attempt_id, v_payment_id,
      r.landlord_user_id, r.payout_account_id, p.razorpay_account_id,
      r.total_amount_paise, r.owner_share_paise, r.admin_share_paise
    )
    ON CONFLICT (rent_record_id) DO NOTHING;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_rent_payment(TEXT, TEXT) TO authenticated;
NOTIFY pgrst, 'reload schema';
