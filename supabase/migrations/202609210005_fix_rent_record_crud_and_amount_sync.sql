-- Keep rent_records as the financial source of truth while preserving the
-- recurring agreement as schedule/configuration only.
CREATE INDEX IF NOT EXISTS rent_records_recurring_agreement_period_idx
  ON public.rent_records(recurring_rent_agreement_id, period_start_date, period_end_date);
CREATE UNIQUE INDEX IF NOT EXISTS rent_records_recurring_period_unique
  ON public.rent_records(recurring_rent_agreement_id, period_start_date, period_end_date)
  WHERE recurring_rent_agreement_id IS NOT NULL;

-- Return the updated row through the existing VOID-compatible RPC contract and
-- keep financial snapshots synchronized when an unpaid record amount changes.
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
  v_amount DECIMAL;
  v_paid DECIMAL;
  v_status public.rent_status_enum;
  v_total BIGINT;
  v_admin BIGINT;
  v_owner BIGINT;
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
    RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update rent records.';
  END IF;
  SELECT * INTO r FROM public.rent_records WHERE rent_record_id=p_rent_record_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Rent record not found.'; END IF;
  v_paid := COALESCE(p_amount_paid, r.amount_paid, 0);
  v_amount := COALESCE(p_amount_due, r.amount_due);
  IF v_amount <= 0 OR v_paid < 0 OR v_paid > v_amount THEN RAISE EXCEPTION 'Invalid rent amount or paid amount.'; END IF;
  IF (r.status IN ('PAID','PARTIALLY_PAID') OR COALESCE(r.amount_paid,0) > 0) AND p_amount_due IS NOT NULL AND p_amount_due <> r.amount_due THEN
    RAISE EXCEPTION 'Paid or partially paid rent amounts cannot be changed.';
  END IF;
  IF COALESCE(p_period_end_date,r.period_end_date) < COALESCE(p_period_start_date,r.period_start_date) THEN RAISE EXCEPTION 'Period end date cannot be before period start date.'; END IF;
  IF COALESCE(p_due_date,r.due_date) < COALESCE(p_period_start_date,r.period_start_date) THEN RAISE EXCEPTION 'Due date cannot be before period start date.'; END IF;
  v_total := ROUND(v_amount * 100)::BIGINT;
  v_admin := ROUND(v_total * COALESCE(r.commission_percentage,0) / 100.0)::BIGINT;
  v_owner := v_total - v_admin;
  IF p_status IS NOT NULL THEN v_status := p_status;
  ELSIF v_paid >= v_amount THEN v_status := 'PAID';
  ELSIF v_paid > 0 THEN v_status := 'PARTIALLY_PAID';
  ELSIF COALESCE(p_due_date,r.due_date) < CURRENT_DATE THEN v_status := 'OVERDUE';
  ELSE v_status := CASE WHEN r.status='CANCELLED' THEN 'CANCELLED' ELSE 'DUE' END;
  END IF;
  UPDATE public.rent_records SET due_date=COALESCE(p_due_date,due_date), period_start_date=COALESCE(p_period_start_date,period_start_date), period_end_date=COALESCE(p_period_end_date,period_end_date), amount_due=v_amount, amount_paid=v_paid, total_amount_paise=v_total, admin_share_paise=v_admin, owner_share_paise=v_owner, status=v_status, notes=COALESCE(p_notes,notes), updated_at=NOW() WHERE rent_record_id=p_rent_record_id;
END; $$;

-- Never cascade-delete payment or payout history. Unpaid records are cancelled
-- instead, so the scheduler's unique period key prevents recreation loops.
CREATE OR REPLACE FUNCTION public.delete_rent_record_admin(p_rent_record_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r public.rent_records%ROWTYPE; v_attempts INTEGER; v_transfers INTEGER;
BEGIN
  IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN RAISE EXCEPTION 'Unauthorized: Insufficient privileges.'; END IF;
  SELECT * INTO r FROM public.rent_records WHERE rent_record_id=p_rent_record_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Rent record not found.'; END IF;
  IF r.status IN ('PAID','PARTIALLY_PAID') OR COALESCE(r.amount_paid,0) > 0 THEN RAISE EXCEPTION 'Paid rent records cannot be deleted.'; END IF;
  SELECT COUNT(*) INTO v_attempts FROM public.rent_payment_attempts WHERE rent_record_id=p_rent_record_id AND status <> 'FAILED';
  IF v_attempts > 0 THEN RAISE EXCEPTION 'Rent record has an active payment attempt and cannot be deleted.'; END IF;
  SELECT COUNT(*) INTO v_transfers FROM public.route_transfers WHERE rent_record_id=p_rent_record_id;
  IF v_transfers > 0 THEN RAISE EXCEPTION 'Rent record has a payout transfer and cannot be deleted.'; END IF;
  UPDATE public.rent_notification_queue SET status='FAILED', last_error='Rent record cancelled before notification delivery' WHERE rent_record_id=p_rent_record_id AND status='PENDING';
  UPDATE public.rent_records SET status='CANCELLED', updated_at=NOW(), notes=COALESCE(notes||E'\n','')||'Cancelled by admin.' WHERE rent_record_id=p_rent_record_id;
END; $$;

-- Diagnostic only: identify agreements that have no linked payable record.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relname='recurring_rent_agreement_record_diagnostics' AND n.nspname='public') THEN
    EXECUTE 'CREATE VIEW public.recurring_rent_agreement_record_diagnostics AS
      SELECT a.agreement_id, a.property_id, a.move_in_date, a.monthly_rent,
             EXISTS (SELECT 1 FROM public.rent_records rr WHERE rr.recurring_rent_agreement_id=a.agreement_id AND rr.status <> ''CANCELLED'') AS matching_rent_record_exists
      FROM public.recurring_rent_agreements a';
  END IF;
END $$;
