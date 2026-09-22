-- Final recurring-rent generator. The actual rent_records rows are the
-- source of truth; agreement counters are repaired after each run.

DROP FUNCTION IF EXISTS public.generate_due_recurring_rents(DATE);

CREATE FUNCTION public.generate_due_recurring_rents(p_run_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  a RECORD;
  cursor_start DATE;
  month_start DATE;
  month_end DATE;
  period_end DATE;
  due_date DATE;
  expected_count INTEGER;
  actual_count INTEGER;
  actual_last_end DATE;
  created_count INTEGER := 0;
  checked_count INTEGER := 0;
  completed_count INTEGER := 0;
  rent_id UUID;
  amount NUMERIC;
  days_in_month INTEGER;
  occupied_days INTEGER;
BEGIN
  FOR a IN
    SELECT *
    FROM public.recurring_rent_agreements
    WHERE status IN ('ACTIVE', 'COMPLETED')
    FOR UPDATE SKIP LOCKED
  LOOP
    checked_count := checked_count + 1;
    cursor_start := a.move_in_date;
    expected_count := 0;

    -- Enumerate the complete expected lease calendar, independent of stale
    -- generated_months or last_generated_period_end values.
    WHILE cursor_start <= a.lease_end_date LOOP
      expected_count := expected_count + 1;
      month_start := date_trunc('month', cursor_start)::DATE;
      month_end := (month_start + INTERVAL '1 month - 1 day')::DATE;
      period_end := LEAST(month_end, a.lease_end_date);
      due_date := (month_start + INTERVAL '1 month')::DATE + (a.due_day - 1);

      -- Periods are chronological, so a future due date means all following
      -- periods are future as well.
      EXIT WHEN due_date > p_run_date;

      SELECT rr.rent_record_id
      INTO rent_id
      FROM public.rent_records rr
      WHERE rr.recurring_rent_agreement_id = a.agreement_id
        AND rr.period_start_date = cursor_start
        AND rr.period_end_date = period_end
      LIMIT 1;

      IF rent_id IS NULL THEN
        days_in_month := EXTRACT(DAY FROM month_end)::INTEGER;
        occupied_days := period_end - cursor_start + 1;
        IF cursor_start = month_start AND period_end = month_end THEN
          amount := a.monthly_rent;
        ELSE
          amount := ROUND((a.monthly_rent * occupied_days) / days_in_month, 2);
        END IF;

        rent_id := public.create_rent_record_admin(
          a.property_id, due_date, cursor_start, period_end,
          amount, a.notes, NULL, NULL
        );

        UPDATE public.rent_records
        SET recurring_rent_agreement_id = a.agreement_id
        WHERE rent_record_id = rent_id;

        PERFORM public.enqueue_rent_notifications(rent_id);
        created_count := created_count + 1;
      END IF;

      cursor_start := period_end + 1;
    END LOOP;

    -- Repair metadata from all actual linked records, including cancelled
    -- records, only after creation has completed.
    SELECT COUNT(*)::INTEGER, MAX(rr.period_end_date)
    INTO actual_count, actual_last_end
    FROM public.rent_records rr
    WHERE rr.recurring_rent_agreement_id = a.agreement_id;

    UPDATE public.recurring_rent_agreements
    SET generated_months = actual_count,
        last_generated_period_end = actual_last_end,
        next_period_start = COALESCE(actual_last_end + 1, move_in_date),
        next_due_date = CASE
          WHEN actual_last_end IS NULL THEN (move_in_date + INTERVAL '1 month')::DATE + (due_day - 1)
          ELSE (date_trunc('month', actual_last_end) + INTERVAL '2 months')::DATE + (due_day - 1)
        END,
        status = CASE
          WHEN actual_count >= expected_count
               AND actual_last_end >= lease_end_date THEN 'COMPLETED'
          ELSE 'ACTIVE'
        END,
        updated_at = NOW()
    WHERE agreement_id = a.agreement_id;

    IF actual_count >= expected_count AND actual_last_end >= a.lease_end_date THEN
      completed_count := completed_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'agreements_checked', checked_count,
    'records_created', created_count,
    'notifications_queued', created_count,
    'agreements_completed', completed_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.generate_due_recurring_rents(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_due_recurring_rents(DATE) TO service_role;
