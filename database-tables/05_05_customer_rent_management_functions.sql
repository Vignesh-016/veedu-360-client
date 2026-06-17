-- FILE NAME: 05_05_customer_rent_management_functions.sql
-- Description: Functions for tenants and landlords regarding rent.
-------------------------------------------------------------------------------

-- Function for Tenants to view properties they currently occupy
CREATE OR REPLACE FUNCTION public.get_my_occupied_properties_customer(
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    property_id UUID,
    property_type public.property_type_enum,
    listing_type public.listing_type_enum, -- Should be 'RENTAL'
    -- price DECIMAL, -- This is monthly rent for rentals
    monthly_rent DECIMAL,
    advance_amount DECIMAL,
    area DECIMAL,
    area_unit public.area_unit_enum,
    year_built INTEGER,
    description TEXT,
    details JSONB,
    youtube_url TEXT,
    locality TEXT,
    city TEXT,
    address TEXT,
    pincode INTEGER,
    property_images JSONB, -- Array of {image_id, image_url, description, display_order} non-internal
    landlord_user_id UUID,
    landlord_name TEXT,
    landlord_email TEXT,
    landlord_phone TEXT,
    rent_due_day INTEGER,
    latest_rent_record_id UUID,
    latest_rent_amount_due DECIMAL,
    latest_rent_status public.rent_status_enum,
    latest_rent_due_date DATE,
    updated_at TIMESTAMP WITH TIME ZONE, -- Property updated_at
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
     IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH occupied_props_base AS (
        SELECT
            p.property_id, p.property_type, p.listing_type, p.price AS monthly_rent_val, p.advance_amount, p.area, p.area_unit, p.year_built,
            p.description, p.details, p.youtube_url, p.locality, p.city, p.address, p.pincode,
            (
                SELECT COALESCE(jsonb_agg(
                    jsonb_build_object(
                        'image_id', pi.image_id,
                        'image_url', pi.image_url,
                        'description', pi.description,
                        'display_order', pi.display_order
                    ) ORDER BY pi.display_order ASC
                ), '[]'::jsonb)
                FROM public.property_images pi
                WHERE pi.property_id = p.property_id AND pi.is_internal_image = FALSE
            ) AS property_images_data,
            p.submitter AS landlord_user_id_val,
            (landlord_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS landlord_name_val,
            landlord_auth_user.email::TEXT AS landlord_email_val,
            landlord_auth_user.phone::TEXT AS landlord_phone_val,
            p.rent_due_day AS rent_due_day_val,
            lr.rent_record_id AS latest_rent_record_id_val,
            lr.amount_due AS latest_rent_amount_due_val,
            lr.status AS latest_rent_status_val,
            lr.due_date AS latest_rent_due_date_val,
            p.updated_at AS property_updated_at
        FROM public.properties p
        JOIN auth.users landlord_auth_user ON p.submitter = landlord_auth_user.id -- Landlord is the submitter
        LEFT JOIN LATERAL (
            SELECT rr.rent_record_id, rr.amount_due, rr.status, rr.due_date
            FROM public.rent_records rr
            WHERE rr.property_id = p.property_id AND rr.tenant_user_id = v_current_user_id
            ORDER BY rr.due_date DESC
            LIMIT 1
        ) lr ON true
        WHERE p.tenant = v_current_user_id
          AND p.listing_type = 'RENTAL'
          -- AND p.is_listed = TRUE -- Tenant should see their occupied property even if admin temporarily unlisted it for some reason.
                                -- Or, if is_listed=FALSE means the tenancy ended, then this filter is fine.
                                -- For now, assuming tenant can always see properties they are marked as tenant for.
          AND p.admin_status NOT IN ('SOLD', 'REJECTED', 'SUSPENDED') -- Filter out definitively inactive states
    ),
    props_with_total_count AS (
        SELECT *, COUNT(*) OVER() as total_rows FROM occupied_props_base
    )
    SELECT
        pwc.property_id, pwc.property_type, pwc.listing_type, pwc.monthly_rent_val, pwc.advance_amount, pwc.area, pwc.area_unit, pwc.year_built,
        pwc.description, pwc.details, pwc.youtube_url, pwc.locality, pwc.city, pwc.address, pwc.pincode,
        pwc.property_images_data,
        pwc.landlord_user_id_val, pwc.landlord_name_val, pwc.landlord_email_val, pwc.landlord_phone_val,
        pwc.rent_due_day_val, pwc.latest_rent_record_id_val, pwc.latest_rent_amount_due_val, pwc.latest_rent_status_val, pwc.latest_rent_due_date_val,
        pwc.property_updated_at, pwc.total_rows
    FROM props_with_total_count pwc
    ORDER BY pwc.property_updated_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_occupied_properties_customer(INTEGER, INTEGER) TO authenticated;

-- Function for Tenants to view their outstanding rent dues
CREATE OR REPLACE FUNCTION public.get_my_rent_dues_customer(
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    rent_record_id UUID,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
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
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH my_dues AS (
        SELECT
            rr.rent_record_id,
            rr.property_id,
            p.address AS prop_address,
            p.locality AS prop_locality,
            p.city AS prop_city,
            rr.landlord_user_id,
            (landlord_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS landlord_name_val,
            landlord_auth_user.email::TEXT AS landlord_email_val,
            landlord_auth_user.phone::TEXT AS landlord_phone_val,
            rr.due_date,
            rr.period_start_date,
            rr.period_end_date,
            rr.amount_due,
            rr.amount_paid,
            rr.status
        FROM public.rent_records rr
        JOIN public.properties p ON rr.property_id = p.property_id
        JOIN auth.users landlord_auth_user ON rr.landlord_user_id = landlord_auth_user.id
        WHERE rr.tenant_user_id = v_current_user_id
          AND rr.status IN ('DUE', 'OVERDUE', 'PARTIALLY_PAID')
    ),
    dues_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM my_dues
    )
    SELECT
        dwc.rent_record_id, dwc.property_id, dwc.prop_address, dwc.prop_locality, dwc.prop_city,
        dwc.landlord_user_id, dwc.landlord_name_val, dwc.landlord_email_val, dwc.landlord_phone_val,
        dwc.due_date, dwc.period_start_date, dwc.period_end_date,
        dwc.amount_due, dwc.amount_paid, dwc.status,
        dwc.total_rows
    FROM dues_with_count dwc
    ORDER BY dwc.due_date ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_rent_dues_customer(INTEGER, INTEGER) TO authenticated;

-- Function for Landlords (property submitters) to view rent dues for their properties
CREATE OR REPLACE FUNCTION public.get_property_rent_dues_landlord(
    p_property_id_filter UUID DEFAULT NULL, -- Optional filter by specific property
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    rent_record_id UUID,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    tenant_user_id UUID,
    tenant_name TEXT,
    tenant_email TEXT,
    tenant_phone TEXT,
    due_date DATE,
    period_start_date DATE,
    period_end_date DATE,
    amount_due DECIMAL,
    amount_paid DECIMAL,
    status public.rent_status_enum,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH landlord_dues AS (
        SELECT
            rr.rent_record_id,
            rr.property_id,
            p.address AS prop_address,
            p.locality AS prop_locality,
            p.city AS prop_city,
            rr.tenant_user_id,
            (tenant_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS tenant_name_val,
            tenant_auth_user.email::TEXT AS tenant_email_val,
            tenant_auth_user.phone::TEXT AS tenant_phone_val,
            rr.due_date,
            rr.period_start_date,
            rr.period_end_date,
            rr.amount_due,
            rr.amount_paid,
            rr.status
        FROM public.rent_records rr
        JOIN public.properties p ON rr.property_id = p.property_id
        JOIN auth.users tenant_auth_user ON rr.tenant_user_id = tenant_auth_user.id
        WHERE rr.landlord_user_id = v_current_user_id -- Landlord is the one who created the rent record
          AND p.submitter = v_current_user_id         -- And also the submitter of the property
          AND (p_property_id_filter IS NULL OR rr.property_id = p_property_id_filter)
          AND rr.status IN ('DUE', 'OVERDUE', 'PARTIALLY_PAID')
    ),
    dues_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM landlord_dues
    )
    SELECT
        dwc.rent_record_id, dwc.property_id, dwc.prop_address, dwc.prop_locality, dwc.prop_city,
        dwc.tenant_user_id, dwc.tenant_name_val, dwc.tenant_email_val, dwc.tenant_phone_val,
        dwc.due_date, dwc.period_start_date, dwc.period_end_date,
        dwc.amount_due, dwc.amount_paid, dwc.status,
        dwc.total_rows
    FROM dues_with_count dwc
    ORDER BY dwc.due_date ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_property_rent_dues_landlord(UUID, INTEGER, INTEGER) TO authenticated;

-- Get payment history for a specific property (Landlord access)
CREATE OR REPLACE FUNCTION public.get_property_payment_history_landlord(
    p_property_id_input UUID,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    payment_id UUID,
    rent_record_id UUID,
    payment_date TIMESTAMP WITH TIME ZONE,
    amount_paid DECIMAL,
    payment_method TEXT,
    transaction_ref TEXT,
    rent_due_date DATE,
    rent_period_start_date DATE,
    rent_period_end_date DATE,
    tenant_user_id UUID,
    tenant_name TEXT,
    tenant_email TEXT,
    tenant_phone TEXT,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF NOT public.check_user_is_property_submitter(p_property_id_input, v_current_user_id) THEN
        RAISE EXCEPTION 'User % does not have permission to view payment history for property %.', v_current_user_id, p_property_id_input;
    END IF;

    RETURN QUERY
    WITH payment_history AS (
        SELECT
            rp.payment_id, rp.rent_record_id, rp.payment_date, rp.amount AS amt_paid,
            rp.payment_method, rp.transaction_ref,
            rr.due_date AS rent_due, rr.period_start_date AS rent_period_start, rr.period_end_date AS rent_period_end,
            rr.tenant_user_id AS ten_user_id,
            (tenant_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS ten_name,
            tenant_auth_user.email::TEXT AS ten_email,
            tenant_auth_user.phone::TEXT AS ten_phone
        FROM public.rent_payments rp
        JOIN public.rent_records rr ON rp.rent_record_id = rr.rent_record_id
        JOIN auth.users tenant_auth_user ON rr.tenant_user_id = tenant_auth_user.id
        WHERE rr.property_id = p_property_id_input
          AND rr.landlord_user_id = v_current_user_id -- Ensure payments are for landlord's records
    ),
    history_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM payment_history
    )
    SELECT
        hwc.payment_id, hwc.rent_record_id, hwc.payment_date, hwc.amt_paid,
        hwc.payment_method, hwc.transaction_ref,
        hwc.rent_due, hwc.rent_period_start, hwc.rent_period_end,
        hwc.ten_user_id, hwc.ten_name, hwc.ten_email, hwc.ten_phone,
        hwc.total_rows
    FROM history_with_count hwc
    ORDER BY hwc.payment_date DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_property_payment_history_landlord(UUID, INTEGER, INTEGER) TO authenticated;