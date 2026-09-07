-- WARNING: This rollback permanently removes any Stage 2 split snapshots.
-- It does not modify historical rent fields or any related business table.

DO $$
DECLARE
    v_snapshot_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_snapshot_count
    FROM public.rent_records
    WHERE commission_percentage IS NOT NULL
       OR total_amount_paise IS NOT NULL
       OR admin_share_paise IS NOT NULL
       OR owner_share_paise IS NOT NULL;

    IF v_snapshot_count > 0 THEN
        RAISE WARNING 'Rollback will permanently delete split snapshots from % rent record(s).', v_snapshot_count;
    END IF;
END;
$$;

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

ALTER TABLE public.rent_records
    DROP CONSTRAINT IF EXISTS rent_records_split_sum_check,
    DROP CONSTRAINT IF EXISTS rent_records_owner_share_paise_check,
    DROP CONSTRAINT IF EXISTS rent_records_admin_share_paise_check,
    DROP CONSTRAINT IF EXISTS rent_records_total_amount_paise_check,
    DROP CONSTRAINT IF EXISTS rent_records_commission_percentage_check,
    DROP CONSTRAINT IF EXISTS rent_records_split_snapshot_completeness_check;

ALTER TABLE public.rent_records
    DROP COLUMN IF EXISTS owner_share_paise,
    DROP COLUMN IF EXISTS admin_share_paise,
    DROP COLUMN IF EXISTS total_amount_paise,
    DROP COLUMN IF EXISTS commission_percentage;
