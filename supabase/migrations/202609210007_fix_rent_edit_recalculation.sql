CREATE OR REPLACE FUNCTION public.update_rent_record_admin(
    p_rent_record_id UUID,
    p_due_date DATE DEFAULT NULL,
    p_period_start_date DATE DEFAULT NULL,
    p_period_end_date DATE DEFAULT NULL,
    p_amount_due DECIMAL DEFAULT NULL,
    p_amount_paid DECIMAL DEFAULT NULL,
    p_status public.rent_status_enum DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  r public.rent_records%ROWTYPE;
  a public.recurring_rent_agreements%ROWTYPE;
  v_start DATE;
  v_end DATE;
  v_due DATE;
  v_amount NUMERIC(12,2);
  v_paid NUMERIC(12,2);
  v_total BIGINT;
  v_admin BIGINT;
  v_owner BIGINT;
  v_days INTEGER;
  v_occupied INTEGER;
  v_status public.rent_status_enum;
  v_attempts INTEGER;
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
    RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update rent records.';
  END IF;
  SELECT * INTO r FROM public.rent_records WHERE rent_record_id=p_rent_record_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Rent record not found.'; END IF;

  v_start := COALESCE(p_period_start_date, r.period_start_date);
  v_end := COALESCE(p_period_end_date, r.period_end_date);
  v_paid := COALESCE(p_amount_paid, r.amount_paid, 0);

  IF r.status IN ('PAID','PARTIALLY_PAID') OR COALESCE(r.amount_paid,0) > 0 THEN
    IF p_period_start_date IS NOT NULL OR p_period_end_date IS NOT NULL OR p_amount_due IS NOT NULL THEN
      RAISE EXCEPTION 'Paid or partially paid rent records cannot have their financial period changed.';
    END IF;
  END IF;
  SELECT COUNT(*) INTO v_attempts FROM public.rent_payment_attempts WHERE rent_record_id=p_rent_record_id AND status <> 'FAILED';
  IF v_attempts > 0 AND (p_period_start_date IS NOT NULL OR p_period_end_date IS NOT NULL OR p_amount_due IS NOT NULL) THEN
    RAISE EXCEPTION 'Rent records with an active payment attempt cannot have their financial period changed.';
  END IF;
  IF v_end < v_start THEN RAISE EXCEPTION 'Period end date cannot be before period start date.'; END IF;

  IF r.recurring_rent_agreement_id IS NOT NULL THEN
    SELECT * INTO a FROM public.recurring_rent_agreements WHERE agreement_id=r.recurring_rent_agreement_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Recurring rent agreement not found.'; END IF;
    IF v_start > v_end OR date_trunc('month', v_start) <> date_trunc('month', v_end) THEN
      RAISE EXCEPTION 'Recurring rent period must remain within one calendar month.';
    END IF;
    v_days := EXTRACT(DAY FROM (date_trunc('month', v_start) + INTERVAL '1 month - 1 day'));
    v_occupied := v_end - v_start + 1;
    IF v_start = date_trunc('month', v_start)::date AND v_end = (date_trunc('month', v_start) + INTERVAL '1 month - 1 day')::date THEN
      v_amount := a.monthly_rent;
    ELSE
      v_amount := ROUND(a.monthly_rent * v_occupied / v_days, 2);
    END IF;
    v_due := (date_trunc('month', v_end) + INTERVAL '1 month')::date + (a.due_day - 1);
    v_total := ROUND(v_amount * 100)::BIGINT;
    v_admin := ROUND(v_total * COALESCE(r.commission_percentage,0) / 100.0)::BIGINT;
    v_owner := v_total - v_admin;
  ELSE
    v_amount := COALESCE(p_amount_due, r.amount_due);
    v_due := COALESCE(p_due_date, r.due_date);
    IF v_amount <= 0 THEN RAISE EXCEPTION 'Amount due must be positive.'; END IF;
    v_total := CASE WHEN r.total_amount_paise IS NULL THEN NULL ELSE ROUND(v_amount * 100)::BIGINT END;
    v_admin := CASE WHEN v_total IS NULL THEN NULL ELSE ROUND(v_total * COALESCE(r.commission_percentage,0) / 100.0)::BIGINT END;
    v_owner := CASE WHEN v_total IS NULL THEN NULL ELSE v_total - v_admin END;
  END IF;

  IF v_due < v_start THEN RAISE EXCEPTION 'Due date cannot be before period start date.'; END IF;
  IF v_paid < 0 OR v_paid > v_amount THEN RAISE EXCEPTION 'Invalid paid amount.'; END IF;
  IF p_status IS NOT NULL THEN v_status := p_status;
  ELSIF v_paid >= v_amount THEN v_status := 'PAID';
  ELSIF v_paid > 0 THEN v_status := 'PARTIALLY_PAID';
  ELSIF v_due < CURRENT_DATE THEN v_status := 'OVERDUE';
  ELSE v_status := CASE WHEN r.status='CANCELLED' THEN 'CANCELLED' ELSE 'DUE' END;
  END IF;

  UPDATE public.rent_records SET
    period_start_date=v_start, period_end_date=v_end, due_date=v_due,
    amount_due=v_amount, amount_paid=v_paid,
    total_amount_paise=v_total, admin_share_paise=v_admin, owner_share_paise=v_owner,
    status=v_status, notes=COALESCE(p_notes,notes), updated_at=NOW()
  WHERE rent_record_id=p_rent_record_id;
END; $$;

GRANT EXECUTE ON FUNCTION public.update_rent_record_admin(UUID, DATE, DATE, DATE, DECIMAL, DECIMAL, public.rent_status_enum, TEXT) TO authenticated;
