-- The transaction_ref uniqueness is a partial index in the existing schema.
-- A bare ON CONFLICT (transaction_ref) cannot infer that index (42P10).
-- Payment-attempt locking and the PAID early return provide the idempotency
-- boundary, so use a non-targeted conflict handler for the ledger insert.

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
  admin_email TEXT;
  tenant_email TEXT;
  tenant_name TEXT;
  property_name TEXT;
BEGIN
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

  IF a.status = 'PAID' THEN
    RETURN;
  END IF;

  IF r.status = 'CANCELLED' THEN
    RAISE EXCEPTION 'Rent is cancelled.';
  END IF;

  UPDATE public.rent_payment_attempts
  SET status = 'PAID',
      razorpay_payment_id = COALESCE(razorpay_payment_id, p_payment_id),
      failure_reason = NULL,
      updated_at = NOW()
  WHERE payment_attempt_id = a.payment_attempt_id;

  UPDATE public.rent_records
  SET status = 'PAID',
      amount_paid = (a.amount_paise::NUMERIC / 100),
      paid_at = NOW(),
      updated_at = NOW()
  WHERE rent_record_id = r.rent_record_id;

  INSERT INTO public.rent_payments(
    rent_record_id, paid_by_user_id, amount, payment_date,
    payment_method, transaction_ref, notes
  ) VALUES (
    r.rent_record_id, a.tenant_user_id, (a.amount_paise::NUMERIC / 100),
    NOW(), 'RAZORPAY', p_payment_id, 'Online rent payment'
  ) ON CONFLICT DO NOTHING;

  SELECT email, raw_user_meta_data->>'full_name'
  INTO tenant_email, tenant_name
  FROM auth.users
  WHERE id = r.tenant_user_id;

  SELECT address INTO property_name
  FROM public.properties
  WHERE property_id = r.property_id;

  SELECT email INTO admin_email
  FROM auth.users u
  JOIN public.admins ad ON ad.user_id = u.id
  ORDER BY u.created_at
  LIMIT 1;

  IF tenant_email IS NOT NULL THEN
    INSERT INTO public.rent_notification_queue(
      rent_record_id, recipient_email, recipient_type, notification_type,
      subject, body
    ) VALUES (
      r.rent_record_id, tenant_email, 'TENANT', 'RENT_PAID',
      'Rent Payment Received - Veedu360',
      'Hello ' || COALESCE(tenant_name, '') || E',\n\nWe have successfully received your rent payment.\n\nProperty: '
      || property_name || E'\nRental Period: ' || r.period_start_date || ' to '
      || r.period_end_date || E'\nAmount Paid: INR ' || r.amount_due
      || E'\nStatus: Paid\nPayment Reference: ' || p_payment_id
      || E'\n\nThank you.\nVeedu360 Property Management'
    ) ON CONFLICT DO NOTHING;
  END IF;

  IF admin_email IS NOT NULL THEN
    INSERT INTO public.rent_notification_queue(
      rent_record_id, recipient_email, recipient_type, notification_type,
      subject, body
    ) VALUES (
      r.rent_record_id, admin_email, 'ADMIN', 'RENT_PAID',
      'Rent payment received - ' || property_name,
      'Tenant: ' || COALESCE(tenant_name, tenant_email) || E'\nProperty: '
      || property_name || E'\nPeriod: ' || r.period_start_date || ' to '
      || r.period_end_date || E'\nAmount: INR ' || r.amount_due
      || E'\nPaid at: ' || NOW() || E'\nPayment reference: ' || p_payment_id
    ) ON CONFLICT DO NOTHING;
  END IF;
END;
$$;
