-- FILE NAME: 06_06_admin_team_assignment_workflow_functions.sql
-- Description: Functions to manage team-specific assignments and workflows.
-------------------------------------------------------------------------------

-- ==== Telecalling-Owner-Team Workflow Functions ====

-- Function for telecalling-owner-team or super-admin to list properties assignable for owner contact
CREATE OR REPLACE FUNCTION public.get_assignable_owner_contact_properties_admin(
    p_city_filter TEXT DEFAULT NULL,
    p_pincode_filter INTEGER DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    property_id UUID,
    address TEXT,
    locality TEXT,
    city TEXT,
    pincode INTEGER,
    submitter_name TEXT,
    submitter_phone TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    WITH assignable_props AS (
        SELECT
            p.property_id, p.address, p.locality, p.city, p.pincode,
            u_submitter.raw_user_meta_data->>'full_name' AS s_name,
            u_submitter.phone AS s_phone,
            p.submitted_at
        FROM public.properties p
        JOIN auth.users u_submitter ON p.submitter = u_submitter.id
        LEFT JOIN public.property_owner_contact_assignments poca ON p.property_id = poca.property_id
        WHERE p.admin_status = 'SUBMITTED'
          AND poca.property_id IS NULL -- Not already assigned
          AND (p_city_filter IS NULL OR p.city ILIKE p_city_filter)
          AND (p_pincode_filter IS NULL OR p.pincode = p_pincode_filter)
    ),
    props_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM assignable_props
    )
    SELECT pwc.* FROM props_with_count pwc
    ORDER BY pwc.submitted_at ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_assignable_owner_contact_properties_admin(TEXT, INTEGER, INTEGER, INTEGER) TO authenticated;

-- Function for a telecalling-owner-team member to self-assign a property
CREATE OR REPLACE FUNCTION public.self_assign_property_for_owner_contact_admin(
    p_property_id UUID
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling-owner-team members can self-assign properties.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.properties WHERE property_id = p_property_id AND admin_status = 'SUBMITTED') THEN
        RAISE EXCEPTION 'Property % is not in SUBMITTED state or does not exist.', p_property_id;
    END IF;

    INSERT INTO public.property_owner_contact_assignments (property_id, assigned_admin_id)
    VALUES (p_property_id, v_admin_id)
    ON CONFLICT (property_id) DO NOTHING; -- Avoid error if already assigned (though UI should prevent this)

    IF NOT FOUND AND NOT EXISTS(SELECT 1 FROM public.property_owner_contact_assignments WHERE property_id = p_property_id AND assigned_admin_id = v_admin_id) THEN
         -- This case means another admin just assigned it.
         RAISE EXCEPTION 'Property % was just assigned to another admin. Please select a different property.', p_property_id;
    END IF;

    UPDATE public.properties
    SET admin_status = 'OWNER_CONTACT_PENDING', updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'SUBMITTED'; -- Ensure status changes only if it was SUBMITTED
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.self_assign_property_for_owner_contact_admin(UUID) TO authenticated;

-- Function for super-admin to assign a property to a specific telecalling-owner-team member
CREATE OR REPLACE FUNCTION public.assign_property_to_owner_telecaller_admin(
    p_property_id UUID,
    p_target_admin_id UUID
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can perform this assignment.';
    END IF;

    IF NOT public.user_is_admin_with_role(p_target_admin_id, 'telecalling-owner-team') THEN
        RAISE EXCEPTION 'Target user % is not an active member of telecalling-owner-team.', p_target_admin_id;
    END IF;

    UPDATE public.properties
    SET admin_status = 'OWNER_CONTACT_PENDING', updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status IN ('SUBMITTED', 'OWNER_CONTACT_PENDING'); -- Allow re-assignment

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property % not found or not in a state to be assigned.', p_property_id;
    END IF;

    INSERT INTO public.property_owner_contact_assignments (property_id, assigned_admin_id)
    VALUES (p_property_id, p_target_admin_id)
    ON CONFLICT (property_id) DO UPDATE
    SET assigned_admin_id = EXCLUDED.assigned_admin_id, assigned_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_property_to_owner_telecaller_admin(UUID, UUID) TO authenticated;

-- Function for an admin to unassign a property from owner telecalling
CREATE OR REPLACE FUNCTION public.unassign_property_from_owner_telecaller_admin(p_property_id UUID)
RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
    v_assigned_admin_id UUID;
BEGIN
    SELECT assigned_admin_id INTO v_assigned_admin_id
    FROM public.property_owner_contact_assignments WHERE property_id = p_property_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Property % is not currently assigned for owner contact.', p_property_id;
        RETURN;
    END IF;

    IF NOT (public.current_user_has_role('super-admin') OR v_assigned_admin_id = v_calling_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins or the assigned admin can unassign.';
    END IF;

    DELETE FROM public.property_owner_contact_assignments WHERE property_id = p_property_id;

    UPDATE public.properties
    SET admin_status = 'SUBMITTED', updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'OWNER_CONTACT_PENDING';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.unassign_property_from_owner_telecaller_admin(UUID) TO authenticated;

-- Function for telecalling-owner-team to mark property owner as verified,
-- make listing active, AND unassign from owner telecalling.
CREATE OR REPLACE FUNCTION public.mark_property_owner_verified_admin(
    p_property_id UUID,
    p_verification_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_update_successful BOOLEAN := FALSE;
BEGIN
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling-owner-team can mark owner verified.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.property_owner_contact_assignments WHERE property_id = p_property_id AND assigned_admin_id = v_admin_id) THEN
        RAISE EXCEPTION 'Property % is not assigned to you for owner contact, or assignment record does not exist.', p_property_id;
    END IF;

    UPDATE public.properties
    SET admin_status = 'OWNER_VERIFIED',
        is_listed = TRUE,
        admin_notes = COALESCE(admin_notes || E'\n--- Owner Verification & Auto-Listed (' || v_admin_id || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\n' || p_verification_notes, admin_notes),
        updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'OWNER_CONTACT_PENDING'
    RETURNING TRUE INTO v_update_successful;

    IF NOT v_update_successful THEN
        RAISE EXCEPTION 'Property % could not be updated. Ensure it is in OWNER_CONTACT_PENDING state and assigned to you.', p_property_id;
    ELSE
        RAISE NOTICE 'Property % marked as OWNER_VERIFIED and listed by admin %.', p_property_id, v_admin_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.mark_property_owner_verified_admin(UUID, TEXT) TO authenticated;


-- ==== Marketing-Team Workflow Functions ====

-- Function for marketing-team or super-admin to list properties assignable for marketing visit
CREATE OR REPLACE FUNCTION public.get_assignable_marketing_properties_admin(
    p_city_filter TEXT DEFAULT NULL,
    p_pincode_filter INTEGER DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    property_id UUID,
    address TEXT,
    locality TEXT,
    city TEXT,
    pincode INTEGER,
    submitter_name TEXT,
    owner_verified_at TIMESTAMP WITH TIME ZONE, -- Approximated by property updated_at when status changed
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('marketing-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges.';
    END IF;

    RETURN QUERY
    WITH assignable_props AS (
        SELECT
            p.property_id, p.address, p.locality, p.city, p.pincode,
            u_submitter.raw_user_meta_data->>'full_name' AS s_name,
            p.updated_at AS status_changed_at -- Approximation of verification time
        FROM public.properties p
        JOIN auth.users u_submitter ON p.submitter = u_submitter.id
        LEFT JOIN public.property_marketing_assignments pma ON p.property_id = pma.property_id
        WHERE p.admin_status = 'OWNER_VERIFIED'
          AND pma.property_id IS NULL -- Not already assigned
          AND (p_city_filter IS NULL OR p.city ILIKE p_city_filter)
          AND (p_pincode_filter IS NULL OR p.pincode = p_pincode_filter)
    ),
    props_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM assignable_props
    )
    SELECT pwc.* FROM props_with_count pwc
    ORDER BY pwc.status_changed_at ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_assignable_marketing_properties_admin(TEXT, INTEGER, INTEGER, INTEGER) TO authenticated;


-- Function for super-admin or an automated process to assign a property to marketing team
CREATE OR REPLACE FUNCTION public.assign_property_to_marketer_admin(
    p_property_id UUID,
    p_target_admin_id UUID -- Can be determined by round-robin/pincode logic externally or passed directly
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN -- Or a service role if automated
        RAISE EXCEPTION 'Unauthorized: Only super-admins or designated service can perform this assignment.';
    END IF;

    IF NOT public.user_is_admin_with_role(p_target_admin_id, 'marketing-team') THEN
        RAISE EXCEPTION 'Target user % is not an active member of marketing-team.', p_target_admin_id;
    END IF;

    UPDATE public.properties
    SET admin_status = 'MARKETING_VISIT_PENDING', updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'OWNER_VERIFIED';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property % not found or not in OWNER_VERIFIED state.', p_property_id;
    END IF;

    INSERT INTO public.property_marketing_assignments (property_id, assigned_admin_id)
    VALUES (p_property_id, p_target_admin_id)
    ON CONFLICT (property_id) DO UPDATE
    SET assigned_admin_id = EXCLUDED.assigned_admin_id, assigned_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_property_to_marketer_admin(UUID, UUID) TO authenticated;

-- Function for an admin to unassign a property from marketing
CREATE OR REPLACE FUNCTION public.unassign_property_from_marketer_admin(p_property_id UUID)
RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
    v_assigned_admin_id UUID;
BEGIN
    SELECT assigned_admin_id INTO v_assigned_admin_id
    FROM public.property_marketing_assignments WHERE property_id = p_property_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Property % is not currently assigned for marketing.', p_property_id;
        RETURN;
    END IF;

    IF NOT (public.current_user_has_role('super-admin') OR v_assigned_admin_id = v_calling_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins or the assigned admin can unassign.';
    END IF;

    DELETE FROM public.property_marketing_assignments WHERE property_id = p_property_id;

    UPDATE public.properties
    SET admin_status = 'OWNER_VERIFIED', updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'MARKETING_VISIT_PENDING';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.unassign_property_from_marketer_admin(UUID) TO authenticated;


-- Function for marketing-team to mark property as marketing verified
CREATE OR REPLACE FUNCTION public.mark_property_marketing_verified_admin(
    p_property_id UUID,
    p_marketing_notes TEXT DEFAULT NULL -- Optional notes from the marketer
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.current_user_has_role('marketing-team') THEN
        RAISE EXCEPTION 'Unauthorized: Only marketing-team can mark marketing verified.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.property_marketing_assignments WHERE property_id = p_property_id AND assigned_admin_id = v_admin_id) THEN
        RAISE EXCEPTION 'Property % is not assigned to you or does not exist in marketing assignments.', p_property_id;
    END IF;

    UPDATE public.properties
    SET admin_status = 'MARKETING_VERIFIED', -- Or 'AWAITING_LISTING' if that's the next step
        admin_notes = COALESCE(admin_notes || E'\n--- Marketing Verification (' || v_admin_id || ' @ ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI') || ') ---\n' || p_marketing_notes, admin_notes),
        updated_at = CURRENT_TIMESTAMP
    WHERE property_id = p_property_id AND admin_status = 'MARKETING_VISIT_PENDING';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Property % could not be updated. Ensure it is in MARKETING_VISIT_PENDING state and assigned to you.', p_property_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.mark_property_marketing_verified_admin(UUID, TEXT) TO authenticated;

-- Function for Super-Admin to set the public listing status of a property
CREATE OR REPLACE FUNCTION public.set_property_listing_status_admin(
    p_property_id UUID,
    p_make_listed BOOLEAN,
    p_new_admin_status public.property_admin_status_enum DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_current_admin_status public.property_admin_status_enum;
    v_current_is_listed BOOLEAN;
    v_auth_user_id UUID := auth.uid();
    v_can_perform_action BOOLEAN := FALSE;
BEGIN
    -- Authorization Check
    SELECT EXISTS (
        SELECT 1 FROM public.admins a
        WHERE a.user_id = v_auth_user_id
          AND a.is_active = TRUE
          AND (
            'super-admin' = ANY(a.roles) OR
            'telecalling-owner-team' = ANY(a.roles) OR
            'telecalling-tenant-team' = ANY(a.roles)
          )
    ) INTO v_can_perform_action;

    IF NOT v_can_perform_action THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to change public listing status.';
    END IF;

    SELECT admin_status, is_listed INTO v_current_admin_status, v_current_is_listed FROM public.properties WHERE property_id = p_property_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Property % not found.', p_property_id; END IF;

    -- Prevent redundant updates
    IF v_current_is_listed = p_make_listed AND (p_new_admin_status IS NULL OR p_new_admin_status = v_current_admin_status) THEN
        RAISE WARNING 'Property % already has the desired listing status and admin status. No changes made.', p_property_id;
        RETURN;
    END IF;

    -- Logic for appropriate admin_status based on listing action
    IF p_make_listed THEN
        IF v_current_admin_status NOT IN ('OWNER_VERIFIED', 'MARKETING_VERIFIED', 'AWAITING_LISTING', 'SUSPENDED', 'RENTED') THEN
             RAISE WARNING 'Property % (admin_status: %) is being listed. Ensure this is an intended transition.', p_property_id, v_current_admin_status;
        END IF;
        UPDATE public.properties
        SET is_listed = TRUE,
            admin_status = COALESCE(
                p_new_admin_status,
                CASE
                    WHEN v_current_admin_status IN ('OWNER_VERIFIED', 'MARKETING_VERIFIED', 'SUSPENDED') THEN 'AWAITING_LISTING'::public.property_admin_status_enum
                    ELSE admin_status
                END
            ),
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = p_property_id;
    ELSE -- Unlisting
        UPDATE public.properties
        SET is_listed = FALSE,
            admin_status = COALESCE(
                p_new_admin_status,
                CASE
                    WHEN v_current_admin_status NOT IN ('REJECTED', 'SOLD', 'RENTED') THEN 'SUSPENDED'::public.property_admin_status_enum
                    ELSE admin_status
                END
            ),
            updated_at = CURRENT_TIMESTAMP
        WHERE property_id = p_property_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.set_property_listing_status_admin(UUID, BOOLEAN, public.property_admin_status_enum) TO authenticated;

CREATE OR REPLACE FUNCTION public.auto_assign_marketing_tasks_cron_worker()
RETURNS JSONB AS $$
DECLARE
    unassigned_prop RECORD;
    
    chosen_admin_id UUID;
    chosen_assignment_group TEXT;
    
    last_assigned_for_group_admin_id UUID;
    
    admin_candidate_ids_array UUID[]; -- Stores UUIDs of admin candidates for a group
    
    selected_candidate_idx INTEGER;
    admin_loop_idx INTEGER;
    
    assigned_count INTEGER := 0;
    skipped_no_admin_count INTEGER := 0;
    processed_properties_count INTEGER := 0;
    
    current_loop_property_id UUID;
    
    max_properties_to_process_per_run INTEGER := 20;

BEGIN
    RAISE NOTICE '[MARKETING_ASSIGN_CRON] Starting auto-assignment at %', clock_timestamp();

    FOR unassigned_prop IN
        SELECT
            p.property_id,
            p.pincode
        FROM public.properties p
        WHERE p.admin_status = 'OWNER_VERIFIED'
          AND NOT EXISTS (
              SELECT 1 FROM public.property_marketing_assignments pma
              WHERE pma.property_id = p.property_id
          )
        ORDER BY p.updated_at ASC
        LIMIT max_properties_to_process_per_run
    LOOP
        processed_properties_count := processed_properties_count + 1;
        current_loop_property_id := unassigned_prop.property_id;
        chosen_admin_id := NULL;
        chosen_assignment_group := NULL;
        admin_candidate_ids_array := ARRAY[]::UUID[];

        -- 1. Attempt pincode-specific assignment
        IF unassigned_prop.pincode IS NOT NULL THEN
            chosen_assignment_group := 'MARKETING_PINCODE_' || unassigned_prop.pincode::TEXT;

            -- Get admins serving this specific pincode, ordered for consistent round-robin
            SELECT array_agg(adm.user_id ORDER BY adm.user_id)
            INTO admin_candidate_ids_array
            FROM public.admins adm
            WHERE adm.is_active = TRUE
              AND 'marketing-team' = ANY(adm.roles)
              AND adm.served_pincodes @> ARRAY[unassigned_prop.pincode];

            IF array_length(admin_candidate_ids_array, 1) > 0 THEN
                -- Get last assigned for this pincode group
                SELECT rrs.last_assigned_admin_id INTO last_assigned_for_group_admin_id
                FROM public.round_robin_state rrs
                WHERE rrs.assignment_group = chosen_assignment_group;

                selected_candidate_idx := NULL;
                IF last_assigned_for_group_admin_id IS NOT NULL THEN
                    FOR admin_loop_idx IN 1..array_length(admin_candidate_ids_array, 1) LOOP
                        IF admin_candidate_ids_array[admin_loop_idx] = last_assigned_for_group_admin_id THEN
                            selected_candidate_idx := admin_loop_idx % array_length(admin_candidate_ids_array, 1) + 1;
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;
                
                IF selected_candidate_idx IS NULL THEN -- No last assignment or last assigned not in current list
                    chosen_admin_id := admin_candidate_ids_array[1];
                ELSE
                    chosen_admin_id := admin_candidate_ids_array[selected_candidate_idx];
                END IF;
            END IF;
        END IF;

        -- 2. Fallback to global round-robin if no pincode match or property has no pincode
        IF chosen_admin_id IS NULL THEN
            chosen_assignment_group := 'MARKETING_GLOBAL';
            
            -- Get all active marketing admins, ordered for consistent round-robin
            SELECT array_agg(adm.user_id ORDER BY adm.user_id)
            INTO admin_candidate_ids_array
            FROM public.admins adm
            WHERE adm.is_active = TRUE
              AND 'marketing-team' = ANY(adm.roles);

            IF array_length(admin_candidate_ids_array, 1) IS NULL OR array_length(admin_candidate_ids_array, 1) = 0 THEN
                RAISE WARNING '[MARKETING_ASSIGN_CRON] No active marketing admins found for global assignment. Skipping property %.', unassigned_prop.property_id;
                skipped_no_admin_count := skipped_no_admin_count + 1;
                CONTINUE; -- Skip to next property
            END IF;

            -- Get last assigned for global marketing group
            SELECT rrs.last_assigned_admin_id INTO last_assigned_for_group_admin_id
            FROM public.round_robin_state rrs
            WHERE rrs.assignment_group = chosen_assignment_group;

            selected_candidate_idx := NULL;
            IF last_assigned_for_group_admin_id IS NOT NULL THEN
                 FOR admin_loop_idx IN 1..array_length(admin_candidate_ids_array, 1) LOOP
                    IF admin_candidate_ids_array[admin_loop_idx] = last_assigned_for_group_admin_id THEN
                        selected_candidate_idx := admin_loop_idx % array_length(admin_candidate_ids_array, 1) + 1;
                        EXIT;
                    END IF;
                END LOOP;
            END IF;

            IF selected_candidate_idx IS NULL THEN
                chosen_admin_id := admin_candidate_ids_array[1];
            ELSE
                chosen_admin_id := admin_candidate_ids_array[selected_candidate_idx];
            END IF;
        END IF;

        -- 3. Perform assignment if an admin was chosen
        IF chosen_admin_id IS NOT NULL AND chosen_assignment_group IS NOT NULL THEN
            BEGIN
                INSERT INTO public.property_marketing_assignments (property_id, assigned_admin_id, assigned_at)
                VALUES (unassigned_prop.property_id, chosen_admin_id, CURRENT_TIMESTAMP);

                UPDATE public.properties
                SET admin_status = 'MARKETING_VISIT_PENDING',
                    updated_at = CURRENT_TIMESTAMP
                WHERE property_id = unassigned_prop.property_id;

                INSERT INTO public.round_robin_state (assignment_group, last_assigned_admin_id, last_assigned_at)
                VALUES (chosen_assignment_group, chosen_admin_id, CURRENT_TIMESTAMP)
                ON CONFLICT (assignment_group) DO UPDATE
                SET last_assigned_admin_id = EXCLUDED.last_assigned_admin_id,
                    last_assigned_at = EXCLUDED.last_assigned_at,
                    updated_at = CURRENT_TIMESTAMP;
                
                assigned_count := assigned_count + 1;
                RAISE NOTICE '[MARKETING_ASSIGN_CRON] Assigned property % to admin % via group %', unassigned_prop.property_id, chosen_admin_id, chosen_assignment_group;

            EXCEPTION WHEN unique_violation THEN
                RAISE WARNING '[MARKETING_ASSIGN_CRON] Property % was likely assigned concurrently. Skipping.', unassigned_prop.property_id;
            WHEN OTHERS THEN
                RAISE WARNING '[MARKETING_ASSIGN_CRON] Error assigning property %: %', unassigned_prop.property_id, SQLERRM;
            END;
        ELSE
            skipped_no_admin_count := skipped_no_admin_count + 1;
            RAISE WARNING '[MARKETING_ASSIGN_CRON] No suitable admin ultimately chosen for property % (Pincode: %)', unassigned_prop.property_id, unassigned_prop.pincode;
        END IF;
        
    END LOOP;

    RAISE NOTICE '[MARKETING_ASSIGN_CRON] Finished. Processed: %, Assigned: %, Skipped (no admin): %', processed_properties_count, assigned_count, skipped_no_admin_count;

    RETURN jsonb_build_object(
        'status', 'Completed',
        'processed_properties_attempted', processed_properties_count,
        'assigned_count', assigned_count,
        'skipped_no_admin_count', skipped_no_admin_count
    );

END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.auto_assign_marketing_tasks_cron_worker() TO postgres;