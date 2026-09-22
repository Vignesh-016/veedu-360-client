-- Repair stale recurring-agreement cursors from the financial records and
-- generate all periods whose own due date has arrived.

CREATE OR REPLACE FUNCTION public.generate_due_recurring_rents(p_run_date DATE DEFAULT CURRENT_DATE)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  a RECORD;
  cursor_start DATE;
  period_start DATE;
  period_end DATE;
  due_date DATE;
  month_end DATE;
  days_in_month INTEGER;
  occupied_days INTEGER;
  amount NUMERIC;
  rent_id UUID;
  actual_count INTEGER;
  actual_last_end DATE;
  created_count INTEGER := 0;
BEGIN
  FOR a IN
    SELECT *
    FROM public.recurring_rent_agreements
    WHERE status IN ('ACTIVE', 'COMPLETED')
      AND (
        status = 'ACTIVE'
        OR last_generated_period_end IS NULL
        OR last_generated_period_end < lease_end_date
        OR generated_months < auto_generate_months
      )
    FOR UPDATE SKIP LOCKED
  LOOP
    -- rent_records is the source of truth. A cancelled linked row still
    -- represents an existing period and therefore remains in this count.
    SELECT COUNT(*)::INTEGER, MAX(rr.period_end_date)
    INTO actual_count, actual_last_end
    FROM public.rent_records rr
    WHERE rr.recurring_rent_agreement_id = a.agreement_id;

    cursor_start := COALESCE(actual_last_end + 1, a.move_in_date);

    -- Repair stale counters/cursors before catch-up begins.
    UPDATE public.recurring_rent_agreements
    SET generated_months = actual_count,
        last_generated_period_end = actual_last_end,
        next_period_start = cursor_start,
        status = CASE
          WHEN actual_last_end >= lease_end_date THEN 'COMPLETED'
          ELSE 'ACTIVE'
        END,
        updated_at = NOW()
    WHERE agreement_id = a.agreement_id;

    IF actual_last_end >= a.lease_end_date THEN
      CONTINUE;
    END IF;

    LOOP
      EXIT WHEN cursor_start > a.lease_end_date;

      period_start := cursor_start;
      month_end := (date_trunc('month', period_start) + INTERVAL '1 month - 1 day')::DATE;
      period_end := LEAST(month_end, a.lease_end_date);
      due_date := (date_trunc('month', period_start) + INTERVAL '1 month')::DATE
        + (a.due_day - 1);

      EXIT WHEN due_date > p_run_date;

      SELECT rr.rent_record_id
      INTO rent_id
      FROM public.rent_records rr
      WHERE rr.recurring_rent_agreement_id = a.agreement_id
        AND rr.period_start_date = period_start
        AND rr.period_end_date = period_end
      LIMIT 1;

      IF rent_id IS NULL THEN
        days_in_month := EXTRACT(DAY FROM month_end)::INTEGER;
        occupied_days := period_end - period_start + 1;
        IF period_start = date_trunc('month', period_start)::DATE
           AND period_end = month_end THEN
          amount := a.monthly_rent;
        ELSE
          amount := ROUND((a.monthly_rent * occupied_days) / days_in_month, 2);
        END IF;

        rent_id := public.create_rent_record_admin(
          a.property_id, due_date, period_start, period_end,
          amount, a.notes, NULL, NULL
        );

        UPDATE public.rent_records
        SET recurring_rent_agreement_id = a.agreement_id
        WHERE rent_record_id = rent_id;

        PERFORM public.enqueue_rent_notifications(rent_id);
        created_count := created_count + 1;
      END IF;

      actual_count := actual_count + 1;
      cursor_start := period_end + 1;

      UPDATE public.recurring_rent_agreements
      SET generated_months = actual_count,
          last_generated_period_end = period_end,
          next_period_start = cursor_start,
          next_due_date = due_date,
          status = CASE WHEN period_end >= lease_end_date THEN 'COMPLETED' ELSE 'ACTIVE' END,
          updated_at = NOW()
      WHERE agreement_id = a.agreement_id;

      EXIT WHEN period_end >= a.lease_end_date;
    END LOOP;
  END LOOP;

  RETURN created_count;
END;
$$;

REVOKE ALL ON FUNCTION public.generate_due_recurring_rents(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_due_recurring_rents(DATE) TO service_role;
