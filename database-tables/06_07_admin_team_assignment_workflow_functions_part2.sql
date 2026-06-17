-- Description: Functions to manage team-specific assignments and workflows (Tenant Telecalling, Sales).
-------------------------------------------------------------------------------

-- ==== Telecalling-Tenant-Team Workflow Functions ====

-- Function for telecalling-tenant-team or super-admin to list interactions assignable for tenant contact
CREATE OR REPLACE FUNCTION public.get_assignable_tenant_contact_interactions_admin(
    p_property_id_filter UUID DEFAULT NULL,
    p_customer_search_term TEXT DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    interaction_id UUID,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    customer_user_id UUID,
    customer_name TEXT,
    customer_phone TEXT,
    customer_email TEXT,
    requested_visit_time DATE,
    interaction_created_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('telecalling-tenant-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    WITH assignable_interactions AS (
        SELECT
            ci.interaction_id, ci.property_id,
            p.address AS prop_addr, p.locality AS prop_loc,
            ci.user_id AS cust_id,
            u_cust.raw_user_meta_data->>'full_name' AS cust_name_val,
            u_cust.phone AS cust_phone_val,
            u_cust.email AS cust_email_val,
            ci.scheduled_for AS requested_time,
            ci.created_at AS int_created_at
        FROM public.customers_interaction ci
        JOIN public.properties p ON ci.property_id = p.property_id
        JOIN auth.users u_cust ON ci.user_id = u_cust.id
        WHERE ci.status = 'VISIT_PENDING'
          AND ci.assigned_tenant_telecaller_id IS NULL
          AND (p_property_id_filter IS NULL OR ci.property_id = p_property_id_filter)
          AND (p_customer_search_term IS NULL OR (
                u_cust.raw_user_meta_data->>'full_name' ILIKE '%' || p_customer_search_term || '%' OR
                u_cust.email ILIKE '%' || p_customer_search_term || '%' OR
                u_cust.phone ILIKE '%' || p_customer_search_term || '%'
              ))
    ),
    interactions_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM assignable_interactions
    )
    SELECT iwc.* FROM interactions_with_count iwc
    ORDER BY iwc.int_created_at ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_assignable_tenant_contact_interactions_admin(UUID, TEXT, INTEGER, INTEGER) TO authenticated;

-- Function for a telecalling-tenant-team member to self-assign an interaction
CREATE OR REPLACE FUNCTION public.self_assign_interaction_for_tenant_contact_admin(
    p_interaction_id UUID
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT (public.current_user_has_role('telecalling-tenant-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling-tenant-team members can self-assign interactions.';
    END IF;

    UPDATE public.customers_interaction
    SET assigned_tenant_telecaller_id = v_admin_id,
        telecaller_assigned_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
        -- Status remains 'VISIT_PENDING' until telecaller verifies and moves it.
    WHERE interaction_id = p_interaction_id
      AND status = 'VISIT_PENDING'
      AND assigned_tenant_telecaller_id IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Interaction % not found, not in VISIT_PENDING state, or already assigned.', p_interaction_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.self_assign_interaction_for_tenant_contact_admin(UUID) TO authenticated;

-- Function for super-admin to assign an interaction to a specific telecalling-tenant-team member
CREATE OR REPLACE FUNCTION public.assign_interaction_to_tenant_telecaller_admin(
    p_interaction_id UUID,
    p_target_admin_id UUID
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can perform this assignment.';
    END IF;

    IF NOT public.user_is_admin_with_role(p_target_admin_id, 'telecalling-tenant-team') THEN
        RAISE EXCEPTION 'Target user % is not an active member of telecalling-tenant-team.', p_target_admin_id;
    END IF;

    UPDATE public.customers_interaction
    SET assigned_tenant_telecaller_id = p_target_admin_id,
        telecaller_assigned_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
        -- Status could be VISIT_PENDING or already assigned to someone else.
    WHERE interaction_id = p_interaction_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Interaction % not found.', p_interaction_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_interaction_to_tenant_telecaller_admin(UUID, UUID) TO authenticated;

-- Function for an admin to unassign an interaction from tenant telecalling
CREATE OR REPLACE FUNCTION public.unassign_interaction_from_tenant_telecaller_admin(p_interaction_id UUID)
RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
    v_current_assignment public.customers_interaction%ROWTYPE;
BEGIN
    SELECT * INTO v_current_assignment FROM public.customers_interaction WHERE interaction_id = p_interaction_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Interaction % not found.', p_interaction_id;
        RETURN;
    END IF;

    IF v_current_assignment.assigned_tenant_telecaller_id IS NULL THEN
        RAISE WARNING 'Interaction % is not currently assigned to a tenant telecaller.', p_interaction_id;
        RETURN;
    END IF;

    IF NOT (public.current_user_has_role('super-admin') OR v_current_assignment.assigned_tenant_telecaller_id = v_calling_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins or the assigned admin can unassign.';
    END IF;

    UPDATE public.customers_interaction
    SET assigned_tenant_telecaller_id = NULL,
        telecaller_assigned_at = NULL,
        updated_at = CURRENT_TIMESTAMP
        -- Status remains 'VISIT_PENDING' typically
    WHERE interaction_id = p_interaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.unassign_interaction_from_tenant_telecaller_admin(UUID) TO authenticated;

-- Function for telecalling-tenant-team to mark interaction as tenant verified and ready for sales assignment
CREATE OR REPLACE FUNCTION public.mark_interaction_tenant_verified_admin(
    p_interaction_id UUID,
    p_verification_notes TEXT DEFAULT NULL,
    p_updated_scheduled_for DATE DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT (public.current_user_has_role('telecalling-tenant-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling-tenant-team can mark tenant verified.';
    END IF;

    UPDATE public.customers_interaction
    SET status = 'VISIT_CONFIRMED_PENDING_SALES',
        admin_notes = COALESCE(admin_notes || E'\n--- Tenant Verification (' || v_admin_id || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\n' || p_verification_notes, admin_notes),
        scheduled_for = COALESCE(p_updated_scheduled_for, scheduled_for), -- Will now be DATE
        updated_at = CURRENT_TIMESTAMP
    WHERE interaction_id = p_interaction_id
      AND status = 'VISIT_PENDING'
      AND assigned_tenant_telecaller_id = v_admin_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Interaction % could not be updated. Ensure it is in VISIT_PENDING state and assigned to you.', p_interaction_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.mark_interaction_tenant_verified_admin(UUID, TEXT, DATE) TO authenticated; 


-- ==== Sales-Team Workflow Functions ====

-- Function (could be called by cron) to assign pending sales visits
CREATE OR REPLACE FUNCTION public.assign_pending_sales_visits_admin()
RETURNS JSONB AS $$
DECLARE
    interaction_group RECORD;
    sales_admin_candidate RECORD;
    v_assignment_summary JSONB := '[]'::jsonb;
    v_visit_assignment_id UUID;
    v_interactions_for_assignment UUID[];
    v_property_pincodes INTEGER[];
    v_assigned_count INTEGER := 0;
    v_unassigned_groups INTEGER := 0;
    v_relevant_sales_admins UUID[];
    uuid_val UUID;
BEGIN
    RAISE NOTICE 'Starting sales visit assignment process at %', clock_timestamp();

    FOR interaction_group IN
        SELECT
            ci.user_id,
            ci.scheduled_for AS visit_date,
            array_agg(ci.interaction_id) AS interaction_ids,
            array_agg(DISTINCT p.pincode) FILTER (WHERE p.pincode IS NOT NULL) AS distinct_pincodes
        FROM public.customers_interaction ci
        JOIN public.properties p ON ci.property_id = p.property_id
        WHERE ci.status = 'VISIT_CONFIRMED_PENDING_SALES'
        GROUP BY ci.user_id, ci.scheduled_for
        HAVING COUNT(ci.interaction_id) > 0
    LOOP
        v_interactions_for_assignment := interaction_group.interaction_ids;
        v_property_pincodes := interaction_group.distinct_pincodes;
        sales_admin_candidate := NULL;

        SELECT adm.user_id INTO sales_admin_candidate
        FROM public.admins adm
        WHERE 'sales-team' = ANY(adm.roles) AND adm.is_active = TRUE
          AND (cardinality(COALESCE(v_property_pincodes, '{}')) = 0 OR adm.served_pincodes && v_property_pincodes)
        ORDER BY random()
        LIMIT 1;

        IF sales_admin_candidate IS NULL THEN
            SELECT adm.user_id INTO sales_admin_candidate
            FROM public.admins adm
            WHERE 'sales-team' = ANY(adm.roles) AND adm.is_active = TRUE
            ORDER BY random()
            LIMIT 1;
        END IF;

        IF sales_admin_candidate IS NOT NULL THEN
            INSERT INTO public.property_visit_assignments (user_id, visit_date, assigned_sales_admin_id)
            VALUES (interaction_group.user_id, interaction_group.visit_date, sales_admin_candidate.user_id)
            ON CONFLICT (user_id, visit_date) DO UPDATE
            SET assigned_sales_admin_id = EXCLUDED.assigned_sales_admin_id, updated_at = CURRENT_TIMESTAMP
            RETURNING visit_assignment_id INTO v_visit_assignment_id;

            FOREACH uuid_val IN ARRAY v_interactions_for_assignment
            LOOP
                INSERT INTO public.property_visit_assignment_interactions (visit_assignment_id, interaction_id)
                VALUES (v_visit_assignment_id, uuid_val)
                ON CONFLICT DO NOTHING;

                UPDATE public.customers_interaction
                SET status = 'VISIT_SCHEDULED_WITH_SALES',
                    assigned_sales_admin_id = sales_admin_candidate.user_id,
                    updated_at = CURRENT_TIMESTAMP
                WHERE interaction_id = uuid_val AND status = 'VISIT_CONFIRMED_PENDING_SALES';
            END LOOP;

            v_assignment_summary := v_assignment_summary || jsonb_build_object(
                'customer_id', interaction_group.user_id,
                'visit_date', interaction_group.visit_date,
                'assigned_sales_admin_id', sales_admin_candidate.user_id,
                'interaction_count', array_length(v_interactions_for_assignment, 1)
            );
            v_assigned_count := v_assigned_count + 1;
            RAISE NOTICE 'Assigned visits for customer %, date % to sales admin %', interaction_group.user_id, interaction_group.visit_date, sales_admin_candidate.user_id;
        ELSE
            v_unassigned_groups := v_unassigned_groups + 1;
            RAISE WARNING 'No suitable sales admin found for customer %, visit_date %.', interaction_group.user_id, interaction_group.visit_date;
        END IF;
    END LOOP;

    RAISE NOTICE 'Sales visit assignment process finished. Assigned groups: %, Unassigned groups: %', v_assigned_count, v_unassigned_groups;
    RETURN jsonb_build_object('assigned_groups_summary', v_assignment_summary, 'total_assigned_groups', v_assigned_count, 'total_unassigned_groups', v_unassigned_groups);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_pending_sales_visits_admin() TO authenticated;

-- Function for a sales-team admin to view their assigned visits for a given date
CREATE OR REPLACE FUNCTION public.get_my_sales_visits_admin(
    p_visit_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
    visit_assignment_id UUID,
    customer_user_id UUID,
    customer_name TEXT,
    customer_phone TEXT,
    customer_email TEXT,
    property_visits JSONB
) AS $$
DECLARE
    v_sales_admin_id UUID := auth.uid();
BEGIN
    IF NOT (public.current_user_has_role('sales-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only sales-team members can view their visits.';
    END IF;

    RETURN QUERY
    SELECT
        pva.visit_assignment_id,
        pva.user_id AS cust_id,
        (cust_user.raw_user_meta_data->>'full_name')::TEXT AS cust_name_val,
        cust_user.phone::TEXT AS cust_phone_val,
        cust_user.email::TEXT AS cust_email_val,
        (SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'interaction_id', ci.interaction_id,
            'property_id', p.property_id,
            'address', p.address,
            'locality', p.locality,
            'pincode', p.pincode,
            'property_type', p.property_type,
            'latitude', p.latitude,
            'longitude', p.longitude,
            'interaction_status', ci.status,
            'scheduled_for_time', ci.scheduled_for,
            'owner_name', (owner_user.raw_user_meta_data->>'full_name')::TEXT,
            'owner_phone', owner_user.phone::TEXT
         ) ORDER BY ci.scheduled_for ASC), '[]'::jsonb)
         FROM public.property_visit_assignment_interactions pvai
         JOIN public.customers_interaction ci ON pvai.interaction_id = ci.interaction_id
         JOIN public.properties p ON ci.property_id = p.property_id
         LEFT JOIN auth.users owner_user ON p.submitter = owner_user.id
         WHERE pvai.visit_assignment_id = pva.visit_assignment_id
           AND ci.status IN ('VISIT_SCHEDULED_WITH_SALES', 'VISIT_COMPLETED')
        ) AS property_visits_data
    FROM public.property_visit_assignments pva
    JOIN auth.users cust_user ON pva.user_id = cust_user.id
    WHERE pva.assigned_sales_admin_id = v_sales_admin_id
      AND pva.visit_date = p_visit_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_sales_visits_admin(DATE) TO authenticated;

-- Function for sales-team admin to mark an interaction (visit) as completed
CREATE OR REPLACE FUNCTION public.mark_interaction_visit_completed_sales_admin(
    p_interaction_id UUID,
    p_feedback TEXT DEFAULT NULL -- Feedback is optional
) RETURNS VOID AS $$
DECLARE
    v_sales_admin_id UUID := auth.uid();
    v_new_admin_notes TEXT;
BEGIN
    IF NOT public.current_user_has_role('sales-team') THEN
        RAISE EXCEPTION 'Unauthorized: Only sales-team members can mark visits completed.';
    END IF;

    -- Construct the admin_notes update logic carefully
    IF p_feedback IS NOT NULL AND TRIM(p_feedback) <> '' THEN
        -- If new feedback is provided, append it
        SELECT
            COALESCE(ci.admin_notes, '') ||
            (CASE WHEN ci.admin_notes IS NOT NULL AND ci.admin_notes <> '' THEN E'\n\n' ELSE '' END) ||
            E'--- Visit Feedback (' || v_sales_admin_id || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\n' ||
            p_feedback
        INTO v_new_admin_notes
        FROM public.customers_interaction ci
        WHERE ci.interaction_id = p_interaction_id;
    ELSE
        SELECT ci.admin_notes
        INTO v_new_admin_notes
        FROM public.customers_interaction ci
        WHERE ci.interaction_id = p_interaction_id;
    END IF;

    UPDATE public.customers_interaction
    SET status = 'VISIT_COMPLETED',
        visited_at = CURRENT_TIMESTAMP,
        admin_notes = v_new_admin_notes,
        updated_at = CURRENT_TIMESTAMP
    WHERE interaction_id = p_interaction_id
      AND status = 'VISIT_SCHEDULED_WITH_SALES'
      AND assigned_sales_admin_id = v_sales_admin_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Interaction % could not be marked completed. Ensure it is scheduled with you and not already completed/cancelled, or interaction ID not found.', p_interaction_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.mark_interaction_visit_completed_sales_admin(UUID, TEXT) IS 
'Allows a sales-team admin to mark a customer interaction (visit) as completed. Updates status to VISIT_COMPLETED, sets visited_at, and appends optional feedback to admin_notes. Only works for interactions assigned to the calling sales admin and in VISIT_SCHEDULED_WITH_SALES status.';
GRANT EXECUTE ON FUNCTION public.mark_interaction_visit_completed_sales_admin(UUID, TEXT) TO authenticated;

-- Function for sales-team admin to mark an interaction (visit) as cancelled
CREATE OR REPLACE FUNCTION public.mark_interaction_visit_cancelled_sales_admin(
    p_interaction_id UUID,
    p_cancellation_reason TEXT -- Cancellation reason is mandatory
) RETURNS VOID AS $$
DECLARE
    v_sales_admin_id UUID := auth.uid();
    v_new_admin_notes TEXT;
    v_existing_admin_notes TEXT;
BEGIN
    IF NOT public.current_user_has_role('sales-team') THEN
        RAISE EXCEPTION 'Unauthorized: Only sales-team members can mark visits cancelled.';
    END IF;

    IF p_cancellation_reason IS NULL OR TRIM(p_cancellation_reason) = '' THEN
        RAISE EXCEPTION 'Cancellation reason is required and cannot be empty.';
    END IF;

    -- Fetch existing admin_notes first
    SELECT ci.admin_notes
    INTO v_existing_admin_notes
    FROM public.customers_interaction ci
    WHERE ci.interaction_id = p_interaction_id;

    -- If the interaction doesn't exist (unlikely if it passes the UPDATE's WHERE clause later, but good for safety)
    -- or if we just want to ensure the variable is initialized.
    IF NOT FOUND THEN
        -- This case should ideally be caught by the UPDATE statement's WHERE clause later if the ID is wrong.
        -- For constructing notes, if interaction_id was valid but admin_notes was NULL, v_existing_admin_notes would be NULL.
        v_existing_admin_notes := NULL; 
    END IF;

    -- Construct the new admin_notes string
    v_new_admin_notes :=
        COALESCE(v_existing_admin_notes, '') ||
        (CASE WHEN v_existing_admin_notes IS NOT NULL AND v_existing_admin_notes <> '' THEN E'\n\n' ELSE '' END) || -- Add separator
        E'--- Visit Cancellation (' || v_sales_admin_id || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\nReason: ' ||
        TRIM(p_cancellation_reason); -- Ensure reason is trimmed

    UPDATE public.customers_interaction
    SET status = 'VISIT_CANCELLED',
        admin_notes = v_new_admin_notes, -- Use the constructed notes
        visited_at = NULL, -- Ensure visited_at is cleared if it was somehow set
        updated_at = CURRENT_TIMESTAMP
    WHERE interaction_id = p_interaction_id
      AND status = 'VISIT_SCHEDULED_WITH_SALES' -- Can only cancel if scheduled
      AND assigned_sales_admin_id = v_sales_admin_id; -- Must be assigned to this sales admin

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Interaction % could not be marked cancelled. Ensure it is scheduled with you and not already completed/cancelled, or interaction ID not found.', p_interaction_id;
    END IF;

    -- Consider if visit balance should be refunded upon cancellation.
    -- This depends on when it was debited and the cancellation policy.
    -- Example: IF a visit was debited, you might add:
    -- UPDATE public.customers SET visit_balance = visit_balance + 1 WHERE user_id = (SELECT user_id FROM public.customers_interaction WHERE interaction_id = p_interaction_id);
    -- This logic is business-specific and not included by default.
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.mark_interaction_visit_cancelled_sales_admin(UUID, TEXT) IS 
'Allows a sales-team admin to mark a customer interaction (visit) as cancelled. Updates status to VISIT_CANCELLED, appends the cancellation reason to admin_notes. Only works for interactions assigned to the calling sales admin and in VISIT_SCHEDULED_WITH_SALES status. Cancellation reason is mandatory.';
GRANT EXECUTE ON FUNCTION public.mark_interaction_visit_cancelled_sales_admin(UUID, TEXT) TO authenticated;