-- FILE NAME: 06_05_admin_service_vendor_management_functions.sql
-- Description: Functions for admins to manage services and vendors.
-------------------------------------------------------------------------------

-- ==== Service Management Functions ====

-- Function for admins (e.g., super-admin, specific operational roles) to create a new service
CREATE OR REPLACE FUNCTION public.create_service_admin(
    p_service_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_category public.service_category_enum DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_service_id INTEGER;
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN -- Example roles
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create services.';
    END IF;

    IF p_service_name IS NULL OR TRIM(p_service_name) = '' THEN
        RAISE EXCEPTION 'Service name cannot be empty.';
    END IF;

    INSERT INTO public.services (service_name, description, category)
    VALUES (TRIM(p_service_name), p_description, p_category)
    RETURNING service_id INTO v_service_id;

    RETURN v_service_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_service_admin(TEXT, TEXT, public.service_category_enum) TO authenticated;

-- Function for admins to update an existing service
CREATE OR REPLACE FUNCTION public.update_service_admin(
    p_service_id INTEGER,
    p_service_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_category public.service_category_enum DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update services.';
    END IF;

    IF p_service_name IS NULL OR TRIM(p_service_name) = '' THEN
        RAISE EXCEPTION 'Service name cannot be empty.';
    END IF;

    UPDATE public.services
    SET service_name = TRIM(p_service_name),
        description = p_description,
        category = p_category
        -- updated_at trigger handles timestamp
    WHERE service_id = p_service_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Service with ID % not found.', p_service_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_service_admin(INTEGER, TEXT, TEXT, public.service_category_enum) TO authenticated;

-- Function for admins to delete a service
CREATE OR REPLACE FUNCTION public.delete_service_admin(p_service_id INTEGER)
RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to delete services.';
    END IF;

    -- Consider implications: what happens to vendor_services or tickets using this service?
    -- For now, direct delete. Could add checks or cascade.
    DELETE FROM public.services WHERE service_id = p_service_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Service with ID % not found for deletion.', p_service_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_service_admin(INTEGER) TO authenticated;

-- Function for admins to list services
CREATE OR REPLACE FUNCTION public.list_services_admin(
    p_category_filter public.service_category_enum DEFAULT NULL,
    p_search_term TEXT DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    service_id INTEGER,
    service_name TEXT,
    description TEXT,
    category public.service_category_enum,
    created_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN -- Any admin can list services
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    RETURN QUERY
    WITH services_base AS (
      SELECT s.service_id, s.service_name, s.description, s.category, s.created_at
      FROM public.services s
      WHERE (p_category_filter IS NULL OR s.category = p_category_filter)
        AND (p_search_term IS NULL OR (
              s.service_name ILIKE '%' || p_search_term || '%' OR
              s.description ILIKE '%' || p_search_term || '%'
            ))
    ),
    services_with_count AS (
      SELECT *, COUNT(*) OVER() AS total_rows FROM services_base
    )
    SELECT swc.*
    FROM services_with_count swc
    ORDER BY swc.service_name
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_services_admin(public.service_category_enum, TEXT, INTEGER, INTEGER) TO authenticated;


-- ==== Vendor Management Functions ====

-- Function for admins to create a new vendor
CREATE OR REPLACE FUNCTION public.create_vendor_admin(
    p_company_name TEXT,
    p_contact_name TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_status vendor_status_enum DEFAULT 'ACTIVE',
    p_notes TEXT DEFAULT NULL,
    p_service_ids INTEGER[] DEFAULT NULL -- Optional: assign services upon creation
) RETURNS UUID AS $$
DECLARE
    v_vendor_id UUID;
    service_id_item INTEGER;
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN -- Example roles
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create vendors.';
    END IF;

    IF p_company_name IS NULL OR TRIM(p_company_name) = '' THEN
        RAISE EXCEPTION 'Company name cannot be empty.';
    END IF;
    IF p_email IS NOT NULL AND p_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format for vendor.';
    END IF;

    INSERT INTO public.vendors (company_name, contact_name, phone, email, address, status, notes)
    VALUES (TRIM(p_company_name), p_contact_name, p_phone, p_email, p_address, p_status, p_notes)
    RETURNING vendor_id INTO v_vendor_id;

    IF p_service_ids IS NOT NULL THEN
        FOREACH service_id_item IN ARRAY p_service_ids LOOP
            IF EXISTS (SELECT 1 FROM public.services s WHERE s.service_id = service_id_item) THEN
                INSERT INTO public.vendor_services (vendor_id, service_id)
                VALUES (v_vendor_id, service_id_item)
                ON CONFLICT (vendor_id, service_id) DO NOTHING;
            ELSE
                RAISE WARNING 'Service ID % provided for new vendor does not exist and was skipped.', service_id_item;
            END IF;
        END LOOP;
    END IF;

    RETURN v_vendor_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_vendor_admin(TEXT, TEXT, TEXT, TEXT, TEXT, vendor_status_enum, TEXT, INTEGER[]) TO authenticated;

-- Function for admins to update an existing vendor's details
CREATE OR REPLACE FUNCTION public.update_vendor_admin(
    p_vendor_id UUID,
    p_company_name TEXT DEFAULT NULL,
    p_contact_name TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL,
    p_address TEXT DEFAULT NULL,
    p_status vendor_status_enum DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update vendors.';
    END IF;

    IF p_email IS NOT NULL AND p_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format for vendor update.';
    END IF;

    UPDATE public.vendors
    SET company_name = COALESCE(TRIM(p_company_name), company_name),
        contact_name = COALESCE(p_contact_name, contact_name),
        phone = COALESCE(p_phone, phone),
        email = COALESCE(p_email, email),
        address = COALESCE(p_address, address),
        status = COALESCE(p_status, status),
        notes = COALESCE(p_notes, notes)
        -- updated_at trigger handles timestamp
    WHERE vendor_id = p_vendor_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vendor with ID % not found.', p_vendor_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_vendor_admin(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, vendor_status_enum, TEXT) TO authenticated;

-- Function for admins to get details of a specific vendor, including their services
CREATE OR REPLACE FUNCTION public.get_vendor_details_admin(p_vendor_id_input UUID)
RETURNS TABLE (
    vendor_id UUID,
    company_name TEXT,
    contact_name TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    status vendor_status_enum,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    services JSONB -- Array of {service_id, service_name, category}
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    RETURN QUERY
    SELECT
        v.vendor_id, v.company_name, v.contact_name, v.phone, v.email, v.address, v.status, v.notes,
        v.created_at, v.updated_at,
        COALESCE(
            (SELECT jsonb_agg(jsonb_build_object(
                'service_id', s.service_id,
                'service_name', s.service_name,
                'category', s.category
             ) ORDER BY s.service_name)
            FROM public.vendor_services vs
            JOIN public.services s ON vs.service_id = s.service_id
            WHERE vs.vendor_id = v.vendor_id),
            '[]'::jsonb
        ) AS services_data
    FROM public.vendors v
    WHERE v.vendor_id = p_vendor_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_vendor_details_admin(UUID) TO authenticated;

-- Function for admins to delete a vendor
CREATE OR REPLACE FUNCTION public.delete_vendor_admin(p_vendor_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to delete vendors.';
    END IF;

    -- Consider implications: tickets assigned to this vendor? Set to NULL or restrict.
    -- For now, direct delete.
    DELETE FROM public.vendors WHERE vendor_id = p_vendor_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Vendor with ID % not found for deletion.', p_vendor_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_vendor_admin(UUID) TO authenticated;

-- Function for admins to assign a service to a vendor
CREATE OR REPLACE FUNCTION public.assign_service_to_vendor_admin(
    p_vendor_id_input UUID,
    p_service_id_input INTEGER
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.vendors WHERE vendor_id = p_vendor_id_input) THEN
        RAISE EXCEPTION 'Vendor with ID % not found.', p_vendor_id_input;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.services WHERE service_id = p_service_id_input) THEN
        RAISE EXCEPTION 'Service with ID % not found.', p_service_id_input;
    END IF;

    INSERT INTO public.vendor_services (vendor_id, service_id)
    VALUES (p_vendor_id_input, p_service_id_input)
    ON CONFLICT (vendor_id, service_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_service_to_vendor_admin(UUID, INTEGER) TO authenticated;

-- Function for admins to remove a service from a vendor
CREATE OR REPLACE FUNCTION public.remove_service_from_vendor_admin(
    p_vendor_id_input UUID,
    p_service_id_input INTEGER
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('accounts-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    DELETE FROM public.vendor_services
    WHERE vendor_id = p_vendor_id_input AND service_id = p_service_id_input;
    -- No error if not found, it's idempotent.
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.remove_service_from_vendor_admin(UUID, INTEGER) TO authenticated;

-- Function for admins to list vendors with filters
CREATE OR REPLACE FUNCTION public.list_vendors_admin(
    p_status_filter vendor_status_enum DEFAULT NULL,
    p_service_id_filter INTEGER DEFAULT NULL, -- Filter by vendors offering a specific service
    p_search_term TEXT DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    vendor_id UUID,
    company_name TEXT,
    contact_name TEXT,
    phone TEXT,
    email TEXT,
    status vendor_status_enum,
    notes TEXT,
    services_summary TEXT, -- Comma-separated list of service names
    total_count BIGINT
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    RETURN QUERY
    WITH vendors_base AS (
        SELECT
            v.vendor_id, v.company_name, v.contact_name, v.phone, v.email, v.status, v.notes,
            (SELECT string_agg(s.service_name, ', ')
             FROM public.vendor_services vs
             JOIN public.services s ON vs.service_id = s.service_id
             WHERE vs.vendor_id = v.vendor_id
            ) AS services_list_summary
        FROM public.vendors v
        WHERE (p_status_filter IS NULL OR v.status = p_status_filter)
          AND (p_service_id_filter IS NULL OR EXISTS (
                SELECT 1 FROM public.vendor_services vs_filter
                WHERE vs_filter.vendor_id = v.vendor_id AND vs_filter.service_id = p_service_id_filter
              ))
          AND (p_search_term IS NULL OR (
                v.company_name ILIKE '%' || p_search_term || '%' OR
                v.contact_name ILIKE '%' || p_search_term || '%' OR
                v.email ILIKE '%' || p_search_term || '%' OR
                v.phone ILIKE '%' || p_search_term || '%' OR
                v.notes ILIKE '%' || p_search_term || '%'
              ))
    ),
    vendors_with_count AS (
      SELECT *, COUNT(*) OVER() AS total_rows FROM vendors_base
    )
    SELECT vwc.*
    FROM vendors_with_count vwc
    ORDER BY vwc.company_name
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_vendors_admin(vendor_status_enum, INTEGER, TEXT, INTEGER, INTEGER) TO authenticated;