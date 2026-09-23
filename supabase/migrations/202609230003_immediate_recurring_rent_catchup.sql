-- Run the existing recurring generator immediately after agreement creation.
-- The generator remains the single source of truth for period calculation,
-- idempotency, financial snapshots, and RENT_DUE notifications.

CREATE OR REPLACE FUNCTION public.create_recurring_rent_agreement(
  p_property_id UUID,
  p_move_in_date DATE,
  p_monthly_rent NUMERIC,
  p_due_day INTEGER DEFAULT 5,
  p_total_months INTEGER DEFAULT 12,
  p_notes TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_property RECORD;
  v_agreement_id UUID;
  v_rent_record_id UUID;
  v_period_end DATE;
  v_lease_end DATE;
  v_days INTEGER;
  v_occupied_days INTEGER;
  v_first_amount NUMERIC(12,2);
  v_admin_id UUID := auth.uid();
  v_business_date DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF p_move_in_date IS NULL
     OR p_monthly_rent <= 0
     OR p_due_day IS NULL
     OR p_due_day NOT BETWEEN 1 AND 28
     OR p_total_months IS NULL
     OR p_total_months NOT BETWEEN 1 AND 60 THEN
    RAISE EXCEPTION 'Monthly due day must be between 1 and 28.' USING ERRCODE = '22023';
  END IF;

  SELECT property_id, listing_type, tenant, submitter, admin_status
  INTO v_property
  FROM public.properties
  WHERE property_id = p_property_id
  FOR SHARE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Property not found'; END IF;
  IF v_property.listing_type <> 'RENTAL' THEN RAISE EXCEPTION 'Property is not a rental property'; END IF;
  IF v_property.tenant IS NULL THEN RAISE EXCEPTION 'Property has no active tenant assigned'; END IF;
  IF v_property.submitter IS NULL THEN RAISE EXCEPTION 'Property has no owner assigned'; END IF;
  IF v_property.admin_status <> 'RENTED' THEN RAISE EXCEPTION 'Property is not currently in rented status'; END IF;

  IF EXISTS (
    SELECT 1
    FROM public.rental_applications ra
    WHERE ra.property_id = p_property_id
      AND ra.status IN ('TENANCY_ACTIVE', 'LEASE_FINALIZED')
      AND ra.user_id <> v_property.tenant
  ) THEN
    RAISE EXCEPTION 'Current property tenant does not match active rental application';
  END IF;

  v_lease_end := (p_move_in_date + make_interval(months => p_total_months) - INTERVAL '1 day')::DATE;
  v_period_end := LEAST(
    (date_trunc('month', p_move_in_date) + INTERVAL '1 month - 1 day')::DATE,
    v_lease_end
  );
  v_days := EXTRACT(
    DAY FROM (date_trunc('month', p_move_in_date) + INTERVAL '1 month - 1 day')
  )::INTEGER;
  v_occupied_days := v_period_end - p_move_in_date + 1;
  v_first_amount := ROUND(p_monthly_rent * v_occupied_days / v_days, 2);

  INSERT INTO public.recurring_rent_agreements(
    property_id, tenant_user_id, landlord_user_id, move_in_date, key_handover_date,
    monthly_rent, due_day, auto_generate_months, generated_months, next_period_start,
    next_due_date, lease_end_date, status, notes, created_by, created_by_admin
  ) VALUES (
    v_property.property_id, v_property.tenant, v_property.submitter, p_move_in_date, p_move_in_date,
    p_monthly_rent, p_due_day, p_total_months, 1, v_period_end + 1,
    (date_trunc('month', p_move_in_date) + INTERVAL '1 month')::DATE + (p_due_day - 1),
    v_lease_end,
    CASE WHEN v_lease_end <= v_period_end THEN 'COMPLETED' ELSE 'ACTIVE' END,
    p_notes, v_admin_id, v_admin_id
  )
  RETURNING agreement_id INTO v_agreement_id;

  -- Keep first-record creation on the authoritative financial path.
  v_rent_record_id := public.create_rent_record_admin(
    p_property_id,
    (date_trunc('month', p_move_in_date) + INTERVAL '1 month')::DATE + (p_due_day - 1),
    p_move_in_date,
    v_period_end,
    v_first_amount,
    p_notes,
    NULL,
    NULL
  );

  UPDATE public.rent_records
  SET recurring_rent_agreement_id = v_agreement_id
  WHERE rent_record_id = v_rent_record_id;

  PERFORM public.enqueue_rent_notifications(v_rent_record_id);

  -- Reuse the same generator used by daily Cron. It will create only periods
  -- whose calculated due date is already reached and will skip the first row.
  PERFORM public.generate_due_recurring_rents(v_business_date);

  RETURN v_agreement_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_recurring_rent_agreement(UUID, DATE, NUMERIC, INTEGER, INTEGER, TEXT) TO authenticated;
