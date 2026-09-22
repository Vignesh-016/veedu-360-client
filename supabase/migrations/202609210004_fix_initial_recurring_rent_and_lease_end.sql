ALTER TABLE public.recurring_rent_agreements
  ADD COLUMN IF NOT EXISTS lease_end_date DATE;

-- Create the agreement and its first period in one transaction. The rent record
-- is delegated to the existing authoritative admin rent RPC so commission,
-- owner share, payout snapshots, and paise calculations remain unchanged.
CREATE OR REPLACE FUNCTION public.create_recurring_rent_agreement(
  p_property_id UUID, p_move_in_date DATE, p_monthly_rent NUMERIC,
  p_due_day INTEGER DEFAULT 5, p_total_months INTEGER DEFAULT 12, p_notes TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
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
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF p_move_in_date IS NULL OR p_monthly_rent <= 0 OR p_due_day IS NULL OR p_due_day NOT BETWEEN 1 AND 28 OR p_total_months IS NULL OR p_total_months NOT BETWEEN 1 AND 60 THEN
    RAISE EXCEPTION 'Monthly due day must be between 1 and 28.' USING ERRCODE = '22023';
  END IF;
  SELECT property_id, listing_type, tenant, submitter, admin_status INTO v_property
    FROM public.properties WHERE property_id=p_property_id FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Property not found'; END IF;
  IF v_property.listing_type <> 'RENTAL' THEN RAISE EXCEPTION 'Property is not a rental property'; END IF;
  IF v_property.tenant IS NULL THEN RAISE EXCEPTION 'Property has no active tenant assigned'; END IF;
  IF v_property.submitter IS NULL THEN RAISE EXCEPTION 'Property has no owner assigned'; END IF;
  IF v_property.admin_status <> 'RENTED' THEN RAISE EXCEPTION 'Property is not currently in rented status'; END IF;

  v_lease_end := (p_move_in_date + make_interval(months => p_total_months) - INTERVAL '1 day')::date;
  v_period_end := LEAST((date_trunc('month', p_move_in_date) + INTERVAL '1 month - 1 day')::date, v_lease_end);
  v_days := EXTRACT(DAY FROM (date_trunc('month', p_move_in_date) + INTERVAL '1 month - 1 day'));
  v_occupied_days := v_period_end - p_move_in_date + 1;
  v_first_amount := ROUND(p_monthly_rent * v_occupied_days / v_days, 2);

  INSERT INTO public.recurring_rent_agreements(
    property_id, tenant_user_id, landlord_user_id, move_in_date, key_handover_date,
    monthly_rent, due_day, auto_generate_months, generated_months, next_period_start,
    next_due_date, lease_end_date, status, notes, created_by, created_by_admin
  ) VALUES (
    v_property.property_id, v_property.tenant, v_property.submitter, p_move_in_date, p_move_in_date,
    p_monthly_rent, p_due_day, p_total_months, 1, v_period_end + 1,
    (date_trunc('month', p_move_in_date) + INTERVAL '1 month')::date + (p_due_day - 1), v_lease_end,
    CASE WHEN v_lease_end <= v_period_end THEN 'COMPLETED' ELSE 'ACTIVE' END,
    p_notes, v_admin_id, v_admin_id
  ) RETURNING agreement_id INTO v_agreement_id;

  v_rent_record_id := public.create_rent_record_admin(
    p_property_id, (date_trunc('month', p_move_in_date) + INTERVAL '1 month')::date + (p_due_day - 1),
    p_move_in_date, v_period_end, v_first_amount, p_notes, NULL, NULL
  );
  UPDATE public.rent_records SET recurring_rent_agreement_id=v_agreement_id WHERE rent_record_id=v_rent_record_id;
  PERFORM public.enqueue_rent_notifications(v_rent_record_id);
  UPDATE public.recurring_rent_agreements SET last_generated_period_end=v_period_end WHERE agreement_id=v_agreement_id;
  RETURN v_agreement_id;
END; $$;

GRANT EXECUTE ON FUNCTION public.create_recurring_rent_agreement(UUID, DATE, NUMERIC, INTEGER, INTEGER, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.generate_due_recurring_rents(p_run_date DATE DEFAULT CURRENT_DATE) RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE a RECORD; period_start DATE; period_end DATE; due DATE; amount NUMERIC; rid UUID; created INTEGER := 0; days INTEGER; occupied_days INTEGER;
BEGIN
  FOR a IN SELECT * FROM recurring_rent_agreements WHERE status='ACTIVE' AND due_day=EXTRACT(DAY FROM p_run_date) AND generated_months < auto_generate_months FOR UPDATE SKIP LOCKED LOOP
    period_end := LEAST((date_trunc('month', p_run_date)::date - 1), a.lease_end_date);
    period_start := date_trunc('month', period_end)::date;
    IF a.last_generated_period_end IS NOT NULL THEN period_start := a.last_generated_period_end + 1; END IF;
    IF period_start > period_end THEN CONTINUE; END IF;
    days := EXTRACT(DAY FROM (date_trunc('month', period_end) + INTERVAL '1 month - 1 day'));
    occupied_days := period_end - period_start + 1;
    amount := CASE WHEN period_start = date_trunc('month', period_end)::date AND occupied_days = days THEN a.monthly_rent ELSE ROUND(a.monthly_rent * occupied_days / days, 2) END;
    due := p_run_date;
    INSERT INTO rent_records(property_id,tenant_user_id,landlord_user_id,due_date,period_start_date,period_end_date,amount_due,status,notes,recurring_rent_agreement_id)
      VALUES(a.property_id,a.tenant_user_id,a.landlord_user_id,due,period_start,period_end,amount,'DUE',a.notes,a.agreement_id)
      ON CONFLICT (recurring_rent_agreement_id,period_start_date,period_end_date) DO NOTHING RETURNING rent_record_id INTO rid;
    IF rid IS NOT NULL THEN created := created + 1; PERFORM public.enqueue_rent_notifications(rid); END IF;
    UPDATE recurring_rent_agreements SET generated_months=generated_months+1,last_generated_period_end=period_end,next_period_start=period_end+1,next_due_date=(p_run_date + INTERVAL '1 month')::date,status=CASE WHEN generated_months+1 >= auto_generate_months OR period_end >= lease_end_date THEN 'COMPLETED' ELSE 'ACTIVE' END,updated_at=NOW() WHERE agreement_id=a.agreement_id;
  END LOOP; RETURN created;
END; $$;
