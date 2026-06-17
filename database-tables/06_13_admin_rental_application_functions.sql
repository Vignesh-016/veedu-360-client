-- FILE NAME: 06_13_admin_rental_application_functions.sql

-- Description: Functions for admins to manage rental applications.
-------------------------------------------------------------------------------

-- Function 1: admin_get_rental_applications
CREATE OR REPLACE FUNCTION public.admin_get_rental_applications(
    p_status_filter public.rental_application_status_enum[] DEFAULT NULL,
    p_assigned_admin_id_filter UUID DEFAULT NULL,
    p_property_id_filter UUID DEFAULT NULL,
    p_applicant_user_id_filter UUID DEFAULT NULL,
    p_landlord_user_id_filter UUID DEFAULT NULL,
    p_submitted_at_start TIMESTAMPTZ DEFAULT NULL,
    p_submitted_at_end TIMESTAMPTZ DEFAULT NULL,
    p_search_term TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'submitted_at',
    p_sort_direction TEXT DEFAULT 'DESC',
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    application_id UUID,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    applicant_user_id UUID,
    applicant_name TEXT,
    applicant_email TEXT,
    applicant_phone TEXT,
    landlord_user_id UUID,
    landlord_name TEXT,
    application_status public.rental_application_status_enum,
    application_data JSONB,
    assigned_admin_id UUID,
    assigned_admin_name TEXT,
    submitted_at TIMESTAMPTZ,
    status_updated_at TIMESTAMPTZ,
    total_count BIGINT
) AS $$
DECLARE
    v_sql TEXT;
    v_order_by_clause TEXT;
    v_final_sort_by TEXT;
    v_final_sort_direction TEXT;
    v_allowed_sort_columns TEXT[] := ARRAY['submitted_at', 'status_updated_at', 'property_address', 'applicant_name', 'application_status'];
BEGIN
    IF NOT (
        public.current_user_has_role('super-admin') OR
        public.current_user_has_role('telecalling-owner-team') OR
        public.current_user_has_role('telecalling-tenant-team') OR
        public.current_user_has_role('accounts-team')
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to view rental applications.';
    END IF;

    IF p_sort_by IS NOT NULL AND p_sort_by = ANY(v_allowed_sort_columns) THEN
        v_final_sort_by := 'ca.' || quote_ident(p_sort_by);
    ELSE
        v_final_sort_by := 'ca.submitted_at';
    END IF;

    IF p_sort_direction IS NOT NULL AND upper(p_sort_direction) IN ('ASC', 'DESC') THEN
        v_final_sort_direction := upper(p_sort_direction);
    ELSE
        v_final_sort_direction := 'DESC';
    END IF;
    v_order_by_clause := format('ORDER BY %s %s NULLS LAST, ca.application_id ASC', v_final_sort_by, v_final_sort_direction);

    v_sql := $QUERY$
    WITH base_applications AS (
        SELECT
            ra.application_id,
            ra.property_id,
            p.address AS property_address,
            p.locality AS property_locality,
            p.city AS property_city,
            ra.user_id AS applicant_user_id,
            applicant_auth.raw_user_meta_data->>'full_name' AS applicant_name,
            applicant_auth.email::TEXT AS applicant_email,
            applicant_auth.phone::TEXT AS applicant_phone,
            ra.landlord_user_id,
            landlord_auth.raw_user_meta_data->>'full_name' AS landlord_name,
            ra.status AS application_status,
            ra.application_data,
            ra.assigned_admin_id,
            assigned_admin_auth.raw_user_meta_data->>'full_name' AS assigned_admin_name,
            ra.submitted_at,
            ra.status_updated_at
        FROM public.rental_applications ra
        JOIN public.properties p ON ra.property_id = p.property_id
        JOIN auth.users applicant_auth ON ra.user_id = applicant_auth.id
        JOIN auth.users landlord_auth ON ra.landlord_user_id = landlord_auth.id
        LEFT JOIN public.admins assigned_adm ON ra.assigned_admin_id = assigned_adm.user_id
        LEFT JOIN auth.users assigned_admin_auth ON assigned_adm.user_id = assigned_admin_auth.id
        WHERE
            ($1 IS NULL OR ra.status = ANY($1)) AND
            ($2 IS NULL OR ra.assigned_admin_id = $2) AND
            ($3 IS NULL OR ra.property_id = $3) AND
            ($4 IS NULL OR ra.user_id = $4) AND
            ($5 IS NULL OR ra.landlord_user_id = $5) AND
            ($6 IS NULL OR ra.submitted_at >= $6) AND
            ($7 IS NULL OR ra.submitted_at <= $7) AND
            ($8 IS NULL OR (
                ra.application_id::text ILIKE '%' || $8 || '%' OR
                applicant_auth.raw_user_meta_data->>'full_name' ILIKE '%' || $8 || '%' OR
                applicant_auth.email ILIKE '%' || $8 || '%' OR
                p.address ILIKE '%' || $8 || '%' OR
                p.locality ILIKE '%' || $8 || '%'
            ))
    ),
    counted_applications AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM base_applications
    )
    SELECT
        ca.application_id, ca.property_id, ca.property_address, ca.property_locality, ca.property_city,
        ca.applicant_user_id, ca.applicant_name, ca.applicant_email, ca.applicant_phone,
        ca.landlord_user_id, ca.landlord_name, ca.application_status, ca.application_data,
        ca.assigned_admin_id, ca.assigned_admin_name, ca.submitted_at, ca.status_updated_at,
        ca.total_rows
    FROM counted_applications ca
    $QUERY$;

    v_sql := v_sql || ' ' || v_order_by_clause || ' OFFSET $9 LIMIT $10';

    RETURN QUERY EXECUTE v_sql
        USING p_status_filter, p_assigned_admin_id_filter, p_property_id_filter,
              p_applicant_user_id_filter, p_landlord_user_id_filter,
              p_submitted_at_start, p_submitted_at_end, p_search_term,
              p_offset, p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.admin_get_rental_applications(public.rental_application_status_enum[], UUID, UUID, UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT, TEXT, INTEGER, INTEGER) TO authenticated;


-- Function 2: admin_get_rental_application_details
CREATE OR REPLACE FUNCTION public.admin_get_rental_application_details(p_application_id UUID)
RETURNS TABLE (
    application_id UUID,
    property_id UUID,
    user_id UUID,
    interaction_id UUID,
    landlord_user_id UUID,
    application_data JSONB,
    status public.rental_application_status_enum,
    admin_notes TEXT,
    assigned_admin_id UUID,
    submitted_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    status_updated_at TIMESTAMPTZ,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    property_pincode INTEGER,
    property_type public.property_type_enum,
    property_listing_type public.listing_type_enum,
    property_price DECIMAL,
    applicant_name TEXT,
    applicant_email TEXT,
    applicant_phone TEXT,
    applicant_profile_details JSONB,
    landlord_name TEXT,
    landlord_email TEXT,
    landlord_phone TEXT,
    assigned_admin_name TEXT,
    assigned_admin_email TEXT,
    interaction_visit_scheduled_for DATE,
    interaction_visit_completed_at TIMESTAMPTZ,
    interaction_original_status public.interaction_status_enum
) AS $$
BEGIN
    IF NOT (
        public.current_user_has_role('super-admin') OR
        public.current_user_has_role('telecalling-owner-team') OR
        public.current_user_has_role('telecalling-tenant-team') OR
        public.current_user_has_role('accounts-team')
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to view application details.';
    END IF;

    RETURN QUERY
    SELECT
        ra.*,
        p.address, p.locality, p.city, p.pincode, p.property_type, p.listing_type, p.price,
        applicant_auth.raw_user_meta_data->>'full_name',
        applicant_auth.email::TEXT,
        applicant_auth.phone::TEXT,
        cust.profile_details,
        landlord_auth.raw_user_meta_data->>'full_name',
        landlord_auth.email::TEXT,
        landlord_auth.phone::TEXT,
        assigned_admin_auth.raw_user_meta_data->>'full_name',
        assigned_admin_auth.email::TEXT,
        ci.scheduled_for,
        ci.visited_at,
        ci.status
    FROM public.rental_applications ra
    JOIN public.properties p ON ra.property_id = p.property_id
    JOIN auth.users applicant_auth ON ra.user_id = applicant_auth.id
    LEFT JOIN public.customers cust ON ra.user_id = cust.user_id
    JOIN auth.users landlord_auth ON ra.landlord_user_id = landlord_auth.id
    LEFT JOIN public.admins assigned_adm ON ra.assigned_admin_id = assigned_adm.user_id
    LEFT JOIN auth.users assigned_admin_auth ON assigned_adm.user_id = assigned_admin_auth.id
    JOIN public.customers_interaction ci ON ra.interaction_id = ci.interaction_id
    WHERE ra.application_id = p_application_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.admin_get_rental_application_details(UUID) TO authenticated;


-- Function 3: admin_self_assign_rental_application
CREATE OR REPLACE FUNCTION public.admin_self_assign_rental_application(p_application_id UUID)
RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
BEGIN
    IF NOT (
        public.current_user_has_role('telecalling-owner-team') OR
        public.current_user_has_role('telecalling-tenant-team')
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling team members can self-assign applications.';
    END IF;

    UPDATE public.rental_applications
    SET assigned_admin_id = v_calling_admin_id,
        status = 'REVIEW_IN_PROGRESS',
        status_updated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id
      AND assigned_admin_id IS NULL
      AND status = 'SUBMITTED';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application ID % not found, already assigned, or not in SUBMITTED state.', p_application_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_self_assign_rental_application(UUID) TO authenticated;


-- Function 4: admin_assign_rental_application
CREATE OR REPLACE FUNCTION public.admin_assign_rental_application(p_application_id UUID, p_target_admin_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can assign applications to others.';
    END IF;

    IF NOT (
        public.user_is_admin_with_role(p_target_admin_id, 'telecalling-owner-team') OR
        public.user_is_admin_with_role(p_target_admin_id, 'telecalling-tenant-team')
    ) THEN
        RAISE EXCEPTION 'Target admin ID % does not have a required telecalling role.', p_target_admin_id;
    END IF;

    UPDATE public.rental_applications
    SET assigned_admin_id = p_target_admin_id,
        status = CASE WHEN status = 'SUBMITTED' THEN 'REVIEW_IN_PROGRESS'::public.rental_application_status_enum ELSE status END,
        status_updated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application ID % not found.', p_application_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_assign_rental_application(UUID, UUID) TO authenticated;


-- Function 5: admin_unassign_rental_application
CREATE OR REPLACE FUNCTION public.admin_unassign_rental_application(p_application_id UUID)
RETURNS VOID AS $$
DECLARE
    v_current_assigned_admin_id UUID;
BEGIN
    SELECT assigned_admin_id INTO v_current_assigned_admin_id FROM public.rental_applications WHERE application_id = p_application_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application ID % not found.', p_application_id;
    END IF;

    IF NOT (
        public.current_user_has_role('super-admin') OR
        (v_current_assigned_admin_id IS NOT NULL AND v_current_assigned_admin_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins or the currently assigned admin can unassign.';
    END IF;

    UPDATE public.rental_applications
    SET assigned_admin_id = NULL,
        status = 'SUBMITTED', -- Revert to SUBMITTED, assuming it's unassigned to be picked up again
        status_updated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_unassign_rental_application(UUID) TO authenticated;


-- Function 6: admin_update_rental_application_status
CREATE OR REPLACE FUNCTION public.admin_update_rental_application_status(
    p_application_id UUID,
    p_new_status public.rental_application_status_enum,
    p_admin_note TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_current_app public.rental_applications%ROWTYPE;
    v_calling_admin_id UUID := auth.uid();
    v_can_update BOOLEAN := FALSE;
BEGIN
    SELECT * INTO v_current_app FROM public.rental_applications WHERE application_id = p_application_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Application ID % not found.', p_application_id; END IF;

    -- Basic permission: Super-admin or assigned admin can update
    IF public.current_user_has_role('super-admin') OR v_current_app.assigned_admin_id = v_calling_admin_id THEN
        v_can_update := TRUE;
    END IF;

    -- Accounts team can update to/from payment-related statuses
    IF public.current_user_has_role('accounts-team') AND
       (v_current_app.status IN ('APPROVED_AWAITING_PAYMENT', 'PAYMENT_CONFIRMED') OR
        p_new_status IN ('APPROVED_AWAITING_PAYMENT', 'PAYMENT_CONFIRMED')) THEN
        v_can_update := TRUE;
    END IF;

    -- Telecalling teams can update if assigned, or if it's in a state they manage (e.g. SUBMITTED, REVIEW_IN_PROGRESS)
    IF (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team')) THEN
        IF v_current_app.assigned_admin_id = v_calling_admin_id OR
           v_current_app.status IN ('SUBMITTED', 'REVIEW_IN_PROGRESS', 'AWAITING_LANDLORD_CONTACT', 'LANDLORD_INFO_PENDING', 'DOCUMENTS_REQUESTED') THEN
           v_can_update := TRUE;
        END IF;
    END IF;


    IF NOT v_can_update THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to update the status of this application from % to %.', v_current_app.status, p_new_status;
    END IF;

    -- Prevent illegal status transitions (example: cannot go from REJECTED to APPROVED_AWAITING_PAYMENT directly by non-superadmin)
    -- This logic can be expanded based on business rules.
    IF NOT public.current_user_has_role('super-admin') THEN
        IF (v_current_app.status IN ('LANDLORD_REJECTED', 'APPLICATION_WITHDRAWN_CUSTOMER', 'CANCELLED_ADMIN') AND
            p_new_status NOT IN ('LANDLORD_REJECTED', 'APPLICATION_WITHDRAWN_CUSTOMER', 'CANCELLED_ADMIN')) THEN
            RAISE EXCEPTION 'Cannot change status from a final rejected/cancelled state: % to % without super-admin override.', v_current_app.status, p_new_status;
        END IF;
        IF (v_current_app.status = 'TENANCY_ACTIVE' AND p_new_status <> 'TENANCY_ACTIVE') THEN
             RAISE EXCEPTION 'Cannot change status from TENANCY_ACTIVE without super-admin override.';
        END IF;
    END IF;


    UPDATE public.rental_applications
    SET status = p_new_status,
        admin_notes = CASE
                          WHEN p_admin_note IS NOT NULL AND TRIM(p_admin_note) <> '' THEN
                              COALESCE(admin_notes || E'\n\n', '') ||
                              '[' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ' by ' || (SELECT COALESCE(raw_user_meta_data->>'full_name', auth.uid()::TEXT) FROM auth.users WHERE id = v_calling_admin_id) || E'] Status: ' || p_new_status || E'. Notes:\n' ||
                              TRIM(p_admin_note)
                          ELSE
                              COALESCE(admin_notes || E'\n\n', '') ||
                              '[' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ' by ' || (SELECT COALESCE(raw_user_meta_data->>'full_name', auth.uid()::TEXT) FROM auth.users WHERE id = v_calling_admin_id) || E'] Status changed to: ' || p_new_status
                      END,
        status_updated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_update_rental_application_status(UUID, public.rental_application_status_enum, TEXT) TO authenticated;


-- Function 7: admin_add_rental_application_note
CREATE OR REPLACE FUNCTION public.admin_add_rental_application_note(p_application_id UUID, p_note TEXT)
RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
BEGIN
    IF NOT (
        public.current_user_has_role('super-admin') OR
        public.current_user_has_role('telecalling-owner-team') OR
        public.current_user_has_role('telecalling-tenant-team') OR
        public.current_user_has_role('accounts-team')
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to add notes.';
    END IF;

    IF p_note IS NULL OR TRIM(p_note) = '' THEN
        RAISE EXCEPTION 'Note cannot be empty.';
    END IF;

    UPDATE public.rental_applications
    SET admin_notes = COALESCE(admin_notes || E'\n\n', '') ||
                      '[' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ' by ' || (SELECT COALESCE(raw_user_meta_data->>'full_name', auth.uid()::TEXT) FROM auth.users WHERE id = v_calling_admin_id) || E'] Note:\n' ||
                      TRIM(p_note),
        updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Application ID % not found.', p_application_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_add_rental_application_note(UUID, TEXT) TO authenticated;


-- Function 8: admin_finalize_lease_from_application
CREATE OR REPLACE FUNCTION public.admin_finalize_lease_from_application(p_application_id UUID)
RETURNS VOID AS $$
DECLARE
    v_app_data public.rental_applications%ROWTYPE;
    v_calling_admin_id UUID := auth.uid();
    v_can_finalize BOOLEAN := FALSE;
BEGIN
    SELECT * INTO v_app_data FROM public.rental_applications WHERE application_id = p_application_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Application ID % not found.', p_application_id; END IF;

    -- Permission check:
    IF public.current_user_has_role('super-admin') THEN
        v_can_finalize := TRUE;
    ELSIF (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team')) AND
          v_app_data.assigned_admin_id = v_calling_admin_id AND
          v_app_data.status IN ('PAYMENT_CONFIRMED', 'LEASE_FINALIZED') THEN
        v_can_finalize := TRUE;
    ELSIF public.current_user_has_role('accounts-team') AND v_app_data.status = 'PAYMENT_CONFIRMED' THEN
        -- Accounts team can move from PAYMENT_CONFIRMED to LEASE_FINALIZED, but maybe not to TENANCY_ACTIVE directly.
        -- For simplicity now, let's allow them to trigger this if status is PAYMENT_CONFIRMED.
        v_can_finalize := TRUE;
    END IF;

    IF NOT v_can_finalize THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to finalize this lease, or application is not in the correct state (%).', v_app_data.status;
    END IF;

    IF v_app_data.status NOT IN ('PAYMENT_CONFIRMED', 'LEASE_FINALIZED') THEN
        RAISE EXCEPTION 'Application status must be PAYMENT_CONFIRMED or LEASE_FINALIZED to finalize the lease. Current status: %', v_app_data.status;
    END IF;

    -- Check if property already has a tenant (and is not the current applicant)
    IF EXISTS (SELECT 1 FROM public.properties WHERE property_id = v_app_data.property_id AND tenant IS NOT NULL AND tenant <> v_app_data.user_id) THEN
        RAISE EXCEPTION 'Property % is already occupied by another tenant. Cannot finalize lease.', v_app_data.property_id;
    END IF;

    -- Start transaction
    BEGIN
        UPDATE public.rental_applications
        SET status = 'TENANCY_ACTIVE',
            status_updated_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE application_id = p_application_id;

        UPDATE public.properties
        SET tenant = v_app_data.user_id,
            admin_status = 'RENTED',
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = v_app_data.property_id;

        UPDATE public.customers_interaction
        SET status = 'LEASE_CONVERTED',
            updated_at = CURRENT_TIMESTAMP
        WHERE interaction_id = v_app_data.interaction_id;

        -- Optional: Create initial rent records (call another function or inline logic)
        -- PERFORM public.admin_create_initial_rent_records_for_tenancy(v_app_data.property_id, v_app_data.user_id);

        -- Optional: Update other pending applications for the same property
        UPDATE public.rental_applications
        SET status = 'CANCELLED_ADMIN',
            admin_notes = COALESCE(admin_notes || E'\n\n', '') || 'Automatically cancelled as property was leased to another applicant.',
            status_updated_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = v_app_data.property_id
          AND application_id <> p_application_id
          AND status NOT IN ('TENANCY_ACTIVE', 'LEASE_FINALIZED', 'APPLICATION_WITHDRAWN_CUSTOMER', 'LANDLORD_REJECTED', 'CANCELLED_ADMIN');

    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Error during lease finalization for application %: %', p_application_id, SQLERRM;
            RAISE; -- Re-raise the exception to ensure transaction rollback
    END;
    -- End transaction
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.admin_finalize_lease_from_application(UUID) TO authenticated;