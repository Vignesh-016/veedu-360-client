-- Stage 2: snapshot the property management commission when an admin creates rent.
-- Existing rent records intentionally remain NULL because their historical
-- commission cannot be reconstructed reliably.

ALTER TABLE public.rent_records
    ADD COLUMN IF NOT EXISTS commission_percentage DECIMAL(5, 2),
    ADD COLUMN IF NOT EXISTS total_amount_paise BIGINT,
    ADD COLUMN IF NOT EXISTS admin_share_paise BIGINT,
    ADD COLUMN IF NOT EXISTS owner_share_paise BIGINT;

ALTER TABLE public.rent_records
    ADD CONSTRAINT rent_records_split_snapshot_completeness_check CHECK (
        (commission_percentage IS NULL AND total_amount_paise IS NULL AND admin_share_paise IS NULL AND owner_share_paise IS NULL)
        OR
        (commission_percentage IS NOT NULL AND total_amount_paise IS NOT NULL AND admin_share_paise IS NOT NULL AND owner_share_paise IS NOT NULL)
    ),
    ADD CONSTRAINT rent_records_commission_percentage_check CHECK (
        commission_percentage IS NULL OR commission_percentage BETWEEN 0 AND 100
    ),
    ADD CONSTRAINT rent_records_total_amount_paise_check CHECK (
        total_amount_paise IS NULL OR total_amount_paise > 0
    ),
    ADD CONSTRAINT rent_records_admin_share_paise_check CHECK (
        admin_share_paise IS NULL OR admin_share_paise >= 0
    ),
    ADD CONSTRAINT rent_records_owner_share_paise_check CHECK (
        owner_share_paise IS NULL OR owner_share_paise >= 0
    ),
    ADD CONSTRAINT rent_records_split_sum_check CHECK (
        total_amount_paise IS NULL OR admin_share_paise + owner_share_paise = total_amount_paise
    );

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
    v_total_amount_paise BIGINT;
    v_admin_share_paise BIGINT;
    v_owner_share_paise BIGINT;
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create rent records.';
    END IF;

    SELECT p.tenant, p.submitter, p.listing_type, p.price,
           p.management_plan_id, msp.percentage AS commission_percentage
    INTO v_property_info
    FROM public.properties p
    LEFT JOIN public.management_service_plans msp ON msp.plan_id = p.management_plan_id
    WHERE p.property_id = p_property_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Property ID % not found.', p_property_id; END IF;
    IF v_property_info.listing_type <> 'RENTAL' THEN RAISE EXCEPTION 'Property % is not a rental property.', p_property_id; END IF;
    IF v_property_info.tenant IS NULL THEN RAISE EXCEPTION 'Property % is not currently occupied by a tenant.', p_property_id; END IF;
    IF v_property_info.submitter IS NULL THEN RAISE EXCEPTION 'Property % does not have a valid owner (submitter/landlord).', p_property_id; END IF;
    IF v_property_info.management_plan_id IS NULL OR v_property_info.commission_percentage IS NULL THEN
        RAISE EXCEPTION 'Property does not have a valid management plan.';
    END IF;
    IF v_property_info.commission_percentage < 0 OR v_property_info.commission_percentage > 100 THEN
        RAISE EXCEPTION 'Management plan commission percentage must be between 0 and 100.';
    END IF;

    IF p_amount_due IS NULL OR p_amount_due <= 0 THEN RAISE EXCEPTION 'Amount due must be positive.'; END IF;
    IF p_period_end_date < p_period_start_date THEN RAISE EXCEPTION 'Period end date cannot be before start date.'; END IF;
    IF p_due_date < p_period_start_date THEN RAISE EXCEPTION 'Due date cannot be before period start date.'; END IF;

    -- Numeric ROUND is deterministic and rounds an exact half away from zero.
    v_total_amount_paise := ROUND(p_amount_due * 100)::BIGINT;
    v_admin_share_paise := ROUND(v_total_amount_paise * v_property_info.commission_percentage / 100)::BIGINT;
    v_owner_share_paise := v_total_amount_paise - v_admin_share_paise;

    INSERT INTO public.rent_records (
        property_id, tenant_user_id, landlord_user_id, due_date,
        period_start_date, period_end_date, amount_due,
        commission_percentage, total_amount_paise, admin_share_paise, owner_share_paise,
        status, notes
    ) VALUES (
        p_property_id, v_property_info.tenant, v_property_info.submitter, p_due_date,
        p_period_start_date, p_period_end_date, p_amount_due,
        v_property_info.commission_percentage, v_total_amount_paise, v_admin_share_paise, v_owner_share_paise,
        'DUE', p_notes
    ) RETURNING rent_record_id INTO v_rent_record_id;

    RETURN v_rent_record_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.create_rent_record_admin(UUID, DATE, DATE, DATE, DECIMAL, TEXT) TO authenticated;
