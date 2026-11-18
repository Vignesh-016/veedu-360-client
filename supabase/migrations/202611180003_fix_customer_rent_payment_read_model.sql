-- Customer rent screens must use the payment ledger as the source of truth.
CREATE OR REPLACE FUNCTION public.get_my_rent_dues_customer(
  p_offset INTEGER DEFAULT 0,
  p_limit INTEGER DEFAULT 10
) RETURNS TABLE(
  rent_record_id UUID,
  property_id UUID,
  property_address TEXT,
  property_locality TEXT,
  property_city TEXT,
  landlord_user_id UUID,
  landlord_name TEXT,
  landlord_email TEXT,
  landlord_phone TEXT,
  due_date DATE,
  period_start_date DATE,
  period_end_date DATE,
  amount_due DECIMAL,
  amount_paid DECIMAL,
  status public.rent_status_enum,
  total_count BIGINT
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  WITH customer_rents AS (
    SELECT
      rr.*,
      p.address AS property_address,
      p.locality AS property_locality,
      p.city AS property_city,
      u.raw_user_meta_data ->> 'full_name' AS landlord_name,
      u.email::TEXT AS landlord_email,
      u.phone::TEXT AS landlord_phone,
      COALESCE(
        NULLIF((SELECT SUM(rp.amount) FROM public.rent_payments rp WHERE rp.rent_record_id = rr.rent_record_id), 0),
        NULLIF((SELECT SUM(rpa.amount_paise::NUMERIC / 100) FROM public.rent_payment_attempts rpa WHERE rpa.rent_record_id = rr.rent_record_id AND rpa.status = 'PAID'), 0),
        COALESCE(rr.amount_paid, 0)
      ) AS effective_amount_paid
    FROM public.rent_records rr
    JOIN public.properties p ON p.property_id = rr.property_id
    JOIN auth.users u ON u.id = rr.landlord_user_id
    WHERE rr.tenant_user_id = auth.uid()
      AND rr.status <> 'CANCELLED'
  ),
  normalized AS (
    SELECT
      customer_rents.*,
      CASE
        WHEN effective_amount_paid >= amount_due THEN 'PAID'::public.rent_status_enum
        WHEN effective_amount_paid > 0 THEN 'PARTIALLY_PAID'::public.rent_status_enum
        ELSE status
      END AS effective_status
    FROM customer_rents
  ),
  filtered AS (
    SELECT normalized.*, COUNT(*) OVER() AS total_rows
    FROM normalized
    WHERE effective_status IN ('DUE', 'OVERDUE', 'PARTIALLY_PAID')
  )
  SELECT
    rent_record_id, property_id, property_address, property_locality, property_city,
    landlord_user_id, landlord_name, landlord_email, landlord_phone,
    due_date, period_start_date, period_end_date, amount_due,
    effective_amount_paid, effective_status, total_rows
  FROM filtered
  ORDER BY due_date ASC
  OFFSET p_offset
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_rent_dues_customer(INTEGER, INTEGER) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_rent_payment_history_customer()
RETURNS TABLE(
  rent_record_id UUID,
  property_id UUID,
  period_start_date DATE,
  period_end_date DATE,
  due_date DATE,
  amount_due DECIMAL,
  amount_paid DECIMAL,
  status public.rent_status_enum,
  paid_at TIMESTAMPTZ,
  payment_reference TEXT
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT
    rr.rent_record_id,
    rr.property_id,
    rr.period_start_date,
    rr.period_end_date,
    rr.due_date,
    rr.amount_due,
    COALESCE(
      NULLIF((SELECT SUM(rp.amount) FROM public.rent_payments rp WHERE rp.rent_record_id = rr.rent_record_id), 0),
      NULLIF((SELECT SUM(rpa.amount_paise::NUMERIC / 100) FROM public.rent_payment_attempts rpa WHERE rpa.rent_record_id = rr.rent_record_id AND rpa.status = 'PAID'), 0),
      COALESCE(rr.amount_paid, 0)
    ) AS effective_amount_paid,
    CASE
      WHEN COALESCE(
        NULLIF((SELECT SUM(rp.amount) FROM public.rent_payments rp WHERE rp.rent_record_id = rr.rent_record_id), 0),
        NULLIF((SELECT SUM(rpa.amount_paise::NUMERIC / 100) FROM public.rent_payment_attempts rpa WHERE rpa.rent_record_id = rr.rent_record_id AND rpa.status = 'PAID'), 0),
        COALESCE(rr.amount_paid, 0)
      ) >= rr.amount_due THEN 'PAID'::public.rent_status_enum
      WHEN COALESCE(
        NULLIF((SELECT SUM(rp.amount) FROM public.rent_payments rp WHERE rp.rent_record_id = rr.rent_record_id), 0),
        NULLIF((SELECT SUM(rpa.amount_paise::NUMERIC / 100) FROM public.rent_payment_attempts rpa WHERE rpa.rent_record_id = rr.rent_record_id AND rpa.status = 'PAID'), 0),
        COALESCE(rr.amount_paid, 0)
      ) > 0 THEN 'PARTIALLY_PAID'::public.rent_status_enum
      ELSE rr.status
    END AS effective_status,
    COALESCE(
      (SELECT MAX(rp.payment_date) FROM public.rent_payments rp WHERE rp.rent_record_id = rr.rent_record_id),
      (SELECT MAX(rpa.updated_at) FROM public.rent_payment_attempts rpa WHERE rpa.rent_record_id = rr.rent_record_id AND rpa.status = 'PAID')
    ) AS paid_at,
    COALESCE(
      (SELECT rp.transaction_ref FROM public.rent_payments rp WHERE rp.rent_record_id = rr.rent_record_id ORDER BY rp.payment_date DESC LIMIT 1),
      (SELECT rpa.razorpay_payment_id FROM public.rent_payment_attempts rpa WHERE rpa.rent_record_id = rr.rent_record_id AND rpa.status = 'PAID' ORDER BY rpa.updated_at DESC LIMIT 1)
    ) AS payment_reference
  FROM public.rent_records rr
  WHERE rr.tenant_user_id = auth.uid()
    AND rr.status <> 'CANCELLED'
  ORDER BY rr.due_date DESC, rr.period_start_date DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_rent_payment_history_customer() TO authenticated;
NOTIFY pgrst, 'reload schema';
