-- Generate every overdue recurring period in chronological order.
-- The existing rent-record RPC remains the single source of truth for
-- commission, owner share, tenant/landlord snapshots, and paise amounts.

CREATE OR REPLACE FUNCTION public.generate_due_recurring_rents(p_run_date DATE DEFAULT CURRENT_DATE)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  a RECORD;
  cursor_period_start DATE;
  period_end DATE;
  period_due_date DATE;
  period_month_start DATE;
  days_in_month INTEGER;
  occupied_days INTEGER;
  amount NUMERIC;
  rent_id UUID;
  created_count INTEGER := 0;
  next_generated_months INTEGER;
BEGIN
  FOR a IN
    SELECT *
    FROM public.recurring_rent_agreements
    WHERE status IN ('ACTIVE', 'COMPLETED')
      AND status <> 'DISABLED'
      AND (
        status = 'ACTIVE'
        OR last_generated_period_end IS NULL
        OR last_generated_period_end < lease_end_date
        OR generated_months < auto_generate_months
      )
    FOR UPDATE SKIP LOCKED
  LOOP
    cursor_period_start := COALESCE(a.last_generated_period_end + 1, a.move_in_date);
    next_generated_months := COALESCE(a.generated_months, 0);

    LOOP
      EXIT WHEN cursor_period_start > a.lease_end_date;

      period_month_start := date_trunc('month', cursor_period_start)::DATE;
      period_end := LEAST(
        (period_month_start + INTERVAL '1 month - 1 day')::DATE,
        a.lease_end_date
      );

      -- Every period is due on the configured day of the following month.
      period_due_date :=
        (period_month_start + INTERVAL '1 month')::DATE + (a.due_day - 1);

      -- Do not create a future period, but continue catching up older ones.
      EXIT WHEN period_due_date > p_run_date;

      SELECT rr.rent_record_id
      INTO rent_id
      FROM public.rent_records rr
      WHERE rr.recurring_rent_agreement_id = a.agreement_id
        AND rr.period_start_date = cursor_period_start
        AND rr.period_end_date = period_end
      LIMIT 1;

      IF rent_id IS NULL THEN
        days_in_month := EXTRACT(
          DAY FROM (period_month_start + INTERVAL '1 month - 1 day')
        )::INTEGER;
        occupied_days := period_end - cursor_period_start + 1;

        IF cursor_period_start = period_month_start
           AND period_end = (period_month_start + INTERVAL '1 month - 1 day')::DATE THEN
          amount := a.monthly_rent;
        ELSE
          amount := ROUND((a.monthly_rent * occupied_days) / days_in_month, 2);
        END IF;

        rent_id := public.create_rent_record_admin(
          a.property_id,
          period_due_date,
          cursor_period_start,
          period_end,
          amount,
          a.notes,
          NULL,
          NULL
        );

        UPDATE public.rent_records
        SET recurring_rent_agreement_id = a.agreement_id
        WHERE rent_record_id = rent_id;

        -- The queue has a unique rent-record/recipient/type key, so a retry
        -- or a later scheduler run cannot duplicate due notifications.
        PERFORM public.enqueue_rent_notifications(rent_id);
        created_count := created_count + 1;
      END IF;

      -- Existing records, including cancelled records, count as generated.
      -- This preserves idempotency and prevents a cancelled period returning.
      next_generated_months := next_generated_months + 1;
      cursor_period_start := period_end + 1;

      UPDATE public.recurring_rent_agreements
      SET generated_months = next_generated_months,
          last_generated_period_end = period_end,
          next_period_start = cursor_period_start,
          next_due_date = period_due_date,
          status = CASE
            WHEN period_end >= lease_end_date THEN 'COMPLETED'
            ELSE 'ACTIVE'
          END,
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
