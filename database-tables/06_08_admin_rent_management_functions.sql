-- Description: Functions for admins (primarily Accounts Team, Super Admin) to manage rent records and payments.
-------------------------------------------------------------------------------

-- Function for admins to create a new rent record for a property
CREATE OR REPLACE FUNCTION public.create_rent_record_admin(
    p_property_id UUID,
    p_due_date DATE,
    p_period_start_date DATE,
    p_period_end_date DATE,
    p_amount_due DECIMAL,
    p_notes TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_rent_record_id UUID;
    v_property_info RECORD;
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create rent records.';
    END IF;

    SELECT tenant, submitter, listing_type, price
    INTO v_property_info
    FROM public.properties WHERE property_id = p_property_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Property ID % not found.', p_property_id; END IF;
    IF v_property_info.listing_type <> 'RENTAL' THEN RAISE EXCEPTION 'Property % is not a rental property.', p_property_id; END IF;
    IF v_property_info.tenant IS NULL THEN RAISE EXCEPTION 'Property % is not currently occupied by a tenant.', p_property_id; END IF;
    IF v_property_info.submitter IS NULL THEN RAISE EXCEPTION 'Property % does not have a valid owner (submitter/landlord).', p_property_id; END IF;

    IF p_amount_due <= 0 THEN RAISE EXCEPTION 'Amount due must be positive.'; END IF;
    IF p_period_end_date < p_period_start_date THEN RAISE EXCEPTION 'Period end date cannot be before start date.'; END IF;
    IF p_due_date < p_period_start_date THEN RAISE EXCEPTION 'Due date cannot be before period start date.'; END IF;

    INSERT INTO public.rent_records (
        property_id, tenant_user_id, landlord_user_id, due_date,
        period_start_date, period_end_date, amount_due, status, notes
    ) VALUES (
        p_property_id, v_property_info.tenant, v_property_info.submitter, p_due_date,
        p_period_start_date, p_period_end_date, p_amount_due, 'DUE', p_notes
    ) RETURNING rent_record_id INTO v_rent_record_id;

    RETURN v_rent_record_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_rent_record_admin(UUID, DATE, DATE, DATE, DECIMAL, TEXT) TO authenticated;

-- Function for admins to update an existing rent record
CREATE OR REPLACE FUNCTION public.update_rent_record_admin(
    p_rent_record_id UUID,
    p_due_date DATE DEFAULT NULL,
    p_period_start_date DATE DEFAULT NULL,
    p_period_end_date DATE DEFAULT NULL,
    p_amount_due DECIMAL DEFAULT NULL,
    p_amount_paid DECIMAL DEFAULT NULL, -- Admins can directly set amount_paid too
    p_status rent_status_enum DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_current_record public.rent_records%ROWTYPE;
    v_final_status rent_status_enum;
    v_final_amount_paid DECIMAL;
    v_final_amount_due DECIMAL;
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update rent records.';
    END IF;

    SELECT * INTO v_current_record FROM public.rent_records WHERE rent_record_id = p_rent_record_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Rent Record ID % not found.', p_rent_record_id; END IF;

    v_final_amount_paid := COALESCE(p_amount_paid, v_current_record.amount_paid);
    v_final_amount_due := COALESCE(p_amount_due, v_current_record.amount_due);

    IF p_status IS NULL THEN -- Auto-calculate status based on payments if not explicitly provided
        IF v_current_record.status = 'CANCELLED' THEN
             v_final_status = 'CANCELLED'; -- Cannot change status from CANCELLED implicitly
        ELSIF v_final_amount_paid >= v_final_amount_due THEN
            v_final_status = 'PAID';
        ELSIF v_final_amount_paid > 0 THEN
            v_final_status = 'PARTIALLY_PAID';
        ELSIF COALESCE(p_due_date, v_current_record.due_date) < CURRENT_DATE THEN
            v_final_status = 'OVERDUE';
        ELSE
            v_final_status = 'DUE';
        END IF;
    ELSE
        v_final_status = p_status;
    END IF;

    UPDATE public.rent_records
    SET due_date = COALESCE(p_due_date, due_date),
        period_start_date = COALESCE(p_period_start_date, period_start_date),
        period_end_date = COALESCE(p_period_end_date, period_end_date),
        amount_due = v_final_amount_due,
        amount_paid = v_final_amount_paid,
        status = v_final_status,
        notes = COALESCE(p_notes, notes),
        updated_at = CURRENT_TIMESTAMP
    WHERE rent_record_id = p_rent_record_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_rent_record_admin(UUID, DATE, DATE, DATE, DECIMAL, DECIMAL, rent_status_enum, TEXT) TO authenticated;

-- Function for admins to list rent records with filters
CREATE OR REPLACE FUNCTION public.list_rent_records_admin(
    p_property_id_filter UUID DEFAULT NULL,
    p_tenant_user_id_filter UUID DEFAULT NULL,
    p_landlord_user_id_filter UUID DEFAULT NULL,
    p_status_filter public.rent_status_enum DEFAULT NULL,
    p_due_date_start DATE DEFAULT NULL,
    p_due_date_end DATE DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    rent_record_id UUID,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    tenant_user_id UUID,
    tenant_name TEXT,
    tenant_email TEXT,
    tenant_phone TEXT,
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
    notes TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    WITH rent_records_base AS (
        SELECT
            rr.rent_record_id,
            rr.property_id,
            p.address AS prop_addr,
            p.locality AS prop_loc,
            rr.tenant_user_id AS ten_id,
            tenant_user.raw_user_meta_data->>'full_name' AS ten_name,
            tenant_user.email::TEXT AS ten_email_val,
            tenant_user.phone::TEXT AS ten_phone,
            rr.landlord_user_id AS land_id,
            landlord_user.raw_user_meta_data->>'full_name' AS land_name,
            landlord_user.email::TEXT AS land_email_val,
            landlord_user.phone::TEXT AS land_phone,
            rr.due_date, rr.period_start_date, rr.period_end_date, rr.amount_due, rr.amount_paid, rr.status, rr.notes,
            rr.created_at, rr.updated_at
        FROM public.rent_records rr
        JOIN public.properties p ON rr.property_id = p.property_id
        JOIN auth.users tenant_user ON rr.tenant_user_id = tenant_user.id
        JOIN auth.users landlord_user ON rr.landlord_user_id = landlord_user.id
        WHERE (p_property_id_filter IS NULL OR rr.property_id = p_property_id_filter)
          AND (p_tenant_user_id_filter IS NULL OR rr.tenant_user_id = p_tenant_user_id_filter)
          AND (p_landlord_user_id_filter IS NULL OR rr.landlord_user_id = p_landlord_user_id_filter)
          AND (p_status_filter IS NULL OR rr.status = p_status_filter)
          AND (p_due_date_start IS NULL OR rr.due_date >= p_due_date_start)
          AND (p_due_date_end IS NULL OR rr.due_date <= p_due_date_end)
    ),
    records_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM rent_records_base
    )
    SELECT
           rwc.rent_record_id,
           rwc.property_id,
           rwc.prop_addr,
           rwc.prop_loc,
           rwc.ten_id,
           rwc.ten_name,
           rwc.ten_email_val,
           rwc.ten_phone,
           rwc.land_id,
           rwc.land_name,
           rwc.land_email_val,
           rwc.land_phone,
           rwc.due_date, rwc.period_start_date, rwc.period_end_date, rwc.amount_due, rwc.amount_paid,
           rwc.status, rwc.notes, rwc.created_at, rwc.updated_at, rwc.total_rows
    FROM records_with_count rwc
    ORDER BY rwc.due_date DESC, rwc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_rent_records_admin(UUID, UUID, UUID, public.rent_status_enum, DATE, DATE, INTEGER, INTEGER) TO authenticated;

-- Function for admins to get details of a specific rent record, including payments
CREATE OR REPLACE FUNCTION public.get_rent_record_details_admin(p_rent_record_id_input UUID)
RETURNS TABLE (
    rent_record_id UUID,
    property_id UUID,
    property_address TEXT,
    tenant_user_id UUID,
    tenant_name TEXT,
    tenant_phone TEXT,
    landlord_user_id UUID,
    landlord_name TEXT,
    landlord_phone TEXT,
    due_date DATE,
    period_start_date DATE,
    period_end_date DATE,
    amount_due DECIMAL,
    amount_paid DECIMAL,
    status public.rent_status_enum,
    notes TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    payments JSONB
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    SELECT
        rr.rent_record_id,
        rr.property_id,
        p.address AS prop_addr,
        rr.tenant_user_id AS ten_id,
        tenant_user.raw_user_meta_data->>'full_name' AS ten_name,
        tenant_user.phone::TEXT AS ten_phone,
        rr.landlord_user_id AS land_id,
        landlord_user.raw_user_meta_data->>'full_name' AS land_name,
        landlord_user.phone::TEXT AS land_phone,
        rr.due_date, rr.period_start_date, rr.period_end_date, rr.amount_due, rr.amount_paid, rr.status, rr.notes,
        rr.created_at, rr.updated_at,
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'payment_id', rp.payment_id,
                'paid_by_name', payer_user.raw_user_meta_data->>'full_name',
                'amount', rp.amount,
                'payment_date', rp.payment_date,
                'payment_method', rp.payment_method,
                'transaction_ref', rp.transaction_ref,
                'notes', rp.notes
            ) ORDER BY rp.payment_date DESC)
            FROM public.rent_payments rp
            JOIN auth.users payer_user ON rp.paid_by_user_id = payer_user.id
            WHERE rp.rent_record_id = rr.rent_record_id
        ), '[]'::jsonb) AS payments_data
    FROM public.rent_records rr
    JOIN public.properties p ON rr.property_id = p.property_id
    JOIN auth.users tenant_user ON rr.tenant_user_id = tenant_user.id
    JOIN auth.users landlord_user ON rr.landlord_user_id = landlord_user.id
    WHERE rr.rent_record_id = p_rent_record_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_rent_record_details_admin(UUID) TO authenticated;

-- Function for admins to delete a rent record (and its payments)
CREATE OR REPLACE FUNCTION public.delete_rent_record_admin(p_rent_record_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;
    RAISE WARNING 'Deleting rent record % - this will also delete associated payments due to CASCADE constraint on rent_payments table.', p_rent_record_id;
    DELETE FROM public.rent_records WHERE rent_record_id = p_rent_record_id;
    IF NOT FOUND THEN RAISE WARNING 'Rent Record ID % not found.', p_rent_record_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_rent_record_admin(UUID) TO authenticated;

-- Function for admins to manually record a rent payment
CREATE OR REPLACE FUNCTION public.record_rent_payment_admin(
    p_rent_record_id UUID,
    p_amount DECIMAL,
    p_paid_by_user_id UUID, -- Typically tenant, but admin specifies
    p_payment_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    p_payment_method TEXT DEFAULT 'MANUAL_ADMIN_ENTRY',
    p_transaction_ref TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_payment_id UUID;
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.rent_records WHERE rent_record_id = p_rent_record_id) THEN
        RAISE EXCEPTION 'Rent Record ID % not found.', p_rent_record_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_paid_by_user_id) THEN
        RAISE EXCEPTION 'Paid By User ID % not found.', p_paid_by_user_id;
    END IF;
    IF p_amount <= 0 THEN RAISE EXCEPTION 'Payment amount must be positive.'; END IF;

    INSERT INTO public.rent_payments (rent_record_id, paid_by_user_id, amount, payment_date, payment_method, transaction_ref, notes)
    VALUES (p_rent_record_id, p_paid_by_user_id, p_amount, p_payment_date, p_payment_method, p_transaction_ref, p_notes)
    RETURNING payment_id INTO v_payment_id;
    -- The trigger on rent_payments will update the rent_records status and amount_paid.
    RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.record_rent_payment_admin(UUID, DECIMAL, UUID, TIMESTAMPTZ, TEXT, TEXT, TEXT) TO authenticated;

-- Function for admins to delete a specific rent payment
CREATE OR REPLACE FUNCTION public.delete_rent_payment_admin(p_payment_id UUID)
RETURNS VOID AS $$
DECLARE
    v_rent_record_id_affected UUID;
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    SELECT rent_record_id INTO v_rent_record_id_affected FROM public.rent_payments WHERE payment_id = p_payment_id;
    IF NOT FOUND THEN
        RAISE WARNING 'Payment ID % not found.', p_payment_id;
        RETURN;
    END IF;

    RAISE WARNING 'Deleting payment % for rent record %. This will trigger recalculation of the rent record status via trigger.', p_payment_id, v_rent_record_id_affected;
    DELETE FROM public.rent_payments WHERE payment_id = p_payment_id;
    -- The trigger `update_rent_record_on_payment` should handle recalculating parent `rent_records` status.
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_rent_payment_admin(UUID) TO authenticated;

-- Function to generate upcoming rent records (called by cron or manually by admin)
CREATE OR REPLACE FUNCTION public.create_upcoming_rent_records_admin()
RETURNS TABLE (
    created_record_count INTEGER,
    skipped_existing_count INTEGER,
    skipped_no_tenant_count INTEGER,
    processed_eligible_property_count INTEGER
) AS $$
DECLARE
    prop RECORD;
    next_due_date DATE;
    period_start_date DATE;
    period_end_date DATE;
    today DATE := CURRENT_DATE;
    current_year INTEGER := date_part('year', today);
    current_month INTEGER := date_part('month', today);
    current_day INTEGER := date_part('day', today);
    next_due_month INTEGER;
    next_due_year INTEGER;
    v_created_count INTEGER := 0;
    v_skipped_existing INTEGER := 0;
    v_skipped_no_tenant INTEGER := 0;
    v_processed_eligible INTEGER := 0;
BEGIN
    -- Permission check: This should be callable by a super-admin or the postgres user for cron
    IF NOT (public.current_user_has_role('super-admin') OR current_user = 'postgres') THEN
        RAISE EXCEPTION 'Unauthorized to generate rent records.';
    END IF;

    RAISE NOTICE 'Starting create_upcoming_rent_records job at %', clock_timestamp();

    FOR prop IN
        SELECT
            p.property_id, p.tenant, p.submitter AS landlord_user_id, p.rent_due_day, p.price AS rent_amount
        FROM public.properties p
        WHERE p.listing_type = 'RENTAL'
          AND p.admin_status NOT IN ('SOLD', 'REJECTED', 'SUSPENDED', 'SUBMITTED') -- Only for active, non-sold/rejected rentals
          AND p.admin_status = 'RENTED'
          AND p.rent_due_day IS NOT NULL
          AND p.price IS NOT NULL AND p.price > 0
    LOOP
        IF prop.tenant IS NULL THEN
            v_skipped_no_tenant := v_skipped_no_tenant + 1;
            CONTINUE; -- Skip if no tenant
        END IF;

        v_processed_eligible := v_processed_eligible + 1;

        -- Calculate next due date (for the current or next month)
        IF current_day < prop.rent_due_day THEN
            next_due_month := current_month;
            next_due_year := current_year;
        ELSE
            IF current_month = 12 THEN
                next_due_month := 1;
                next_due_year := current_year + 1;
            ELSE
                next_due_month := current_month + 1;
                next_due_year := current_year;
            END IF;
        END IF;

        BEGIN
            next_due_date := make_date(next_due_year, next_due_month, prop.rent_due_day);
        EXCEPTION WHEN invalid_datetime_format THEN
            RAISE WARNING 'Invalid date %-%-% for property %, rent_due_day %. Using last day of month.', next_due_year, next_due_month, prop.rent_due_day, prop.property_id, prop.rent_due_day;
            next_due_date := (make_date(next_due_year, next_due_month, 1) + interval '1 month' - interval '1 day')::DATE;
        END;

        -- Calculate period start and end (assuming monthly rentals ending on due date - 1 day of next month logic)
        -- A common approach: if due_date is 5th, period is 5th of prev month to 4th of current month.
        -- Or, if due_date is 5th, period is 5th of current month to 4th of next month.
        -- Let's assume: period is for the month leading up to the due_date.
        -- If due_date is March 5th, period is Feb 5th to March 4th. Rent is for this period.
        period_end_date := next_due_date - INTERVAL '1 day';
        period_start_date := period_end_date - INTERVAL '1 month' + INTERVAL '1 day';


        IF NOT EXISTS (
            SELECT 1 FROM public.rent_records rr
            WHERE rr.property_id = prop.property_id
              AND rr.tenant_user_id = prop.tenant
              AND rr.due_date = next_due_date
        ) THEN
            BEGIN
                INSERT INTO public.rent_records (
                    property_id, tenant_user_id, landlord_user_id, due_date,
                    period_start_date, period_end_date, amount_due, status
                ) VALUES (
                    prop.property_id, prop.tenant, prop.landlord_user_id, next_due_date,
                    period_start_date, period_end_date, prop.rent_amount, 'DUE'
                );
                v_created_count := v_created_count + 1;
                RAISE NOTICE 'Created rent record for property % (Tenant: %, Due: %)', prop.property_id, prop.tenant, next_due_date;
            EXCEPTION WHEN others THEN
                RAISE WARNING 'Failed to insert rent record for property % (Tenant: %, Due: %): %', prop.property_id, prop.tenant, next_due_date, SQLERRM;
                -- Consider how to handle failures (e.g., log to another table)
            END;
        ELSE
            v_skipped_existing := v_skipped_existing + 1;
        END IF;
    END LOOP;
    RAISE NOTICE 'Finished create_upcoming_rent_records job. Processed Eligible: %, Created: %, Skipped (Existing): %, Skipped (No Tenant): %', v_processed_eligible, v_created_count, v_skipped_existing, v_skipped_no_tenant;
    RETURN QUERY SELECT v_created_count, v_skipped_existing, v_skipped_no_tenant, v_processed_eligible;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_upcoming_rent_records_admin() TO authenticated;
-- GRANT EXECUTE ON FUNCTION public.create_upcoming_rent_records_admin() TO postgres; -- For cron job execution