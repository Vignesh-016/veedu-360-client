-- FILE NAME: 06_12_admin_performance_analytics_functions.sql
-- Description: Functions for Super Admins to view performance analytics of various teams and individuals.
-------------------------------------------------------------------------------

-- Performance analytics for Telecalling Owner Team
CREATE OR REPLACE FUNCTION public.get_telecalling_owner_team_performance_admin(
    p_start_date DATE DEFAULT (CURRENT_DATE - INTERVAL '30 days'),
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_admin_id_filter UUID DEFAULT NULL -- Optional: filter for a specific admin
) RETURNS TABLE (
    admin_id UUID,
    admin_name TEXT,
    properties_verified_count BIGINT, -- Properties moved to OWNER_VERIFIED by this admin in period
    currently_assigned_pending_count BIGINT, -- Properties in OWNER_CONTACT_PENDING currently assigned
    avg_docs_per_verified_property DECIMAL -- Avg property docs added for properties they verified
) AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can view team performance analytics.';
    END IF;

    RETURN QUERY
    WITH admin_actions AS (
        -- Count properties verified by each admin in the period
        -- This requires tracking who moved the property to 'OWNER_VERIFIED'.
        -- Assuming updated_by or a log table would store this. For now, we link through assignment.
        -- This is an approximation: properties whose status became OWNER_VERIFIED while assigned to them.
        SELECT
            poca.assigned_admin_id,
            COUNT(DISTINCT p.property_id) AS verified_count
        FROM public.properties p
        JOIN public.property_owner_contact_assignments poca ON p.property_id = poca.property_id
        -- We need a way to link the status change event to the admin.
        -- Let's assume the 'updated_at' of the property when status changed to OWNER_VERIFIED
        -- happened while it was assigned to this admin during the period. This is imperfect.
        -- A proper audit log table `property_status_changes(property_id, new_status, changed_by_admin_id, changed_at)` would be better.
        -- For now, count properties that are currently OWNER_VERIFIED and were assigned to them.
        WHERE p.admin_status = 'OWNER_VERIFIED'
          AND p.updated_at >= p_start_date AND p.updated_at <= p_end_date -- Property became verified in this period
        GROUP BY poca.assigned_admin_id
    ),
    current_assignments AS (
        SELECT
            poca.assigned_admin_id,
            COUNT(DISTINCT p.property_id) AS current_pending_count
        FROM public.properties p
        JOIN public.property_owner_contact_assignments poca ON p.property_id = poca.property_id
        WHERE p.admin_status = 'OWNER_CONTACT_PENDING'
        GROUP BY poca.assigned_admin_id
    ),
    docs_added AS (
        -- This counts documents uploaded by admins for properties they likely handled
        -- Again, direct attribution is better with an audit log.
        SELECT
            pd.uploaded_by AS admin_id, -- Assuming uploaded_by is the admin_id
            p.property_id,
            COUNT(pd.document_id) as doc_count
        FROM public.property_documents pd
        JOIN public.properties p ON pd.property_id = p.property_id
        JOIN public.property_owner_contact_assignments poca ON p.property_id = poca.property_id AND pd.uploaded_by = poca.assigned_admin_id
        WHERE p.admin_status = 'OWNER_VERIFIED' -- Count docs for properties they helped verify
          AND pd.uploaded_at >= p_start_date AND pd.uploaded_at <= p_end_date
        GROUP BY pd.uploaded_by, p.property_id
    ),
    avg_docs AS (
        SELECT
            da.admin_id,
            AVG(da.doc_count) as avg_doc_per_prop
        FROM docs_added da
        GROUP BY da.admin_id
    )
    SELECT
        adm.user_id AS admin_id,
        COALESCE(u.raw_user_meta_data->>'full_name', adm.user_id::TEXT) AS admin_name,
        COALESCE(aa.verified_count, 0) AS properties_verified_count,
        COALESCE(ca.current_pending_count, 0) AS currently_assigned_pending_count,
        COALESCE(ad.avg_doc_per_prop, 0.0) AS avg_docs_per_verified_property
    FROM public.admins adm
    JOIN auth.users u ON adm.user_id = u.id
    LEFT JOIN admin_actions aa ON adm.user_id = aa.assigned_admin_id
    LEFT JOIN current_assignments ca ON adm.user_id = ca.assigned_admin_id
    LEFT JOIN avg_docs ad ON adm.user_id = ad.admin_id
    WHERE 'telecalling-owner-team' = ANY(adm.roles)
      AND (p_admin_id_filter IS NULL OR adm.user_id = p_admin_id_filter)
    ORDER BY admin_name;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_telecalling_owner_team_performance_admin(DATE, DATE, UUID) TO authenticated;


-- Performance analytics for Sales Team
CREATE OR REPLACE FUNCTION public.get_sales_team_performance_admin(
    p_start_date DATE DEFAULT (CURRENT_DATE - INTERVAL '30 days'),
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_admin_id_filter UUID DEFAULT NULL -- Optional: filter for a specific admin
) RETURNS TABLE (
    admin_id UUID,
    admin_name TEXT,
    total_visit_assignments BIGINT, -- Number of PVA groups assigned
    total_interactions_scheduled BIGINT, -- Sum of interactions in those PVAL groups for the period
    total_interactions_completed BIGINT, -- Interactions marked COMPLETED by this admin in period
    total_interactions_cancelled_by_sales BIGINT -- Interactions marked CANCELLED by this admin
) AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can view team performance analytics.';
    END IF;

    RETURN QUERY
    WITH sales_admin_base AS (
        SELECT adm.user_id, COALESCE(u.raw_user_meta_data->>'full_name', adm.user_id::TEXT) AS name
        FROM public.admins adm
        JOIN auth.users u ON adm.user_id = u.id
        WHERE 'sales-team' = ANY(adm.roles)
          AND (p_admin_id_filter IS NULL OR adm.user_id = p_admin_id_filter)
    ),
    visit_assignments_stats AS (
        SELECT
            pva.assigned_sales_admin_id,
            COUNT(DISTINCT pva.visit_assignment_id) AS pva_count,
            COUNT(pvai.interaction_id) AS interactions_in_pva_count
        FROM public.property_visit_assignments pva
        JOIN public.property_visit_assignment_interactions pvai ON pva.visit_assignment_id = pvai.visit_assignment_id
        WHERE pva.visit_date >= p_start_date AND pva.visit_date <= p_end_date
        GROUP BY pva.assigned_sales_admin_id
    ),
    completed_interactions AS (
        SELECT
            ci.assigned_sales_admin_id, -- Assuming this is correctly updated when sales completes it
            COUNT(ci.interaction_id) AS completed_count
        FROM public.customers_interaction ci
        WHERE ci.status = 'VISIT_COMPLETED'
          AND ci.visited_at >= p_start_date AND ci.visited_at <= p_end_date
        GROUP BY ci.assigned_sales_admin_id
    ),
    cancelled_interactions AS (
        -- Assuming admin_notes or another field indicates who cancelled if it's sales admin
        -- For simplicity, let's count cancellations where they were the assigned sales admin
        -- A more robust way: check who set the status to 'VISIT_CANCELLED' via an audit log.
        SELECT
            ci.assigned_sales_admin_id,
            COUNT(ci.interaction_id) AS cancelled_count
        FROM public.customers_interaction ci
        WHERE ci.status = 'VISIT_CANCELLED'
          AND ci.updated_at >= p_start_date AND ci.updated_at <= p_end_date -- Cancellation happened in period
          -- AND ci.admin_notes ILIKE '%cancelled by sales%' -- This is very weak.
        GROUP BY ci.assigned_sales_admin_id
    )
    SELECT
        sab.user_id AS admin_id,
        sab.name AS admin_name,
        COALESCE(vas.pva_count, 0) AS total_visit_assignments,
        COALESCE(vas.interactions_in_pva_count, 0) AS total_interactions_scheduled,
        COALESCE(ci_comp.completed_count, 0) AS total_interactions_completed,
        COALESCE(ci_canc.cancelled_count, 0) AS total_interactions_cancelled_by_sales
    FROM sales_admin_base sab
    LEFT JOIN visit_assignments_stats vas ON sab.user_id = vas.assigned_sales_admin_id
    LEFT JOIN completed_interactions ci_comp ON sab.user_id = ci_comp.assigned_sales_admin_id
    LEFT JOIN cancelled_interactions ci_canc ON sab.user_id = ci_canc.assigned_sales_admin_id
    ORDER BY admin_name;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_sales_team_performance_admin(DATE, DATE, UUID) TO authenticated;


-- Performance analytics for Ticket Handling Admins (Telecalling Teams, Super Admins)
CREATE OR REPLACE FUNCTION public.get_ticket_handling_performance_admin(
    p_start_date DATE DEFAULT (CURRENT_DATE - INTERVAL '30 days'),
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_admin_id_filter UUID DEFAULT NULL, -- Optional: filter for a specific admin
    p_role_filter public.admin_role_enum DEFAULT NULL -- Optional: filter by role (e.g. 'telecalling-tenant-team')
) RETURNS TABLE (
    admin_id UUID,
    admin_name TEXT,
    roles public.admin_role_enum[],
    tickets_assigned_in_period BIGINT, -- Tickets assigned to this admin where assignment happened in period
    tickets_resolved_in_period BIGINT, -- Tickets moved to RESOLVED by this admin in period
    tickets_closed_in_period BIGINT,   -- Tickets moved to CLOSED by this admin in period
    avg_resolution_time_hours DECIMAL(10,2) -- For tickets resolved in period by this admin
) AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can view team performance analytics.';
    END IF;

    RETURN QUERY
    WITH relevant_admins AS (
        SELECT adm.user_id, COALESCE(u.raw_user_meta_data->>'full_name', adm.user_id::TEXT) AS name, adm.roles
        FROM public.admins adm
        JOIN auth.users u ON adm.user_id = u.id
        WHERE (p_admin_id_filter IS NULL OR adm.user_id = p_admin_id_filter)
          AND (p_role_filter IS NULL OR p_role_filter = ANY(adm.roles))
          AND ( -- Ensure admin is part of ticket handling roles if no specific admin is filtered
                p_admin_id_filter IS NOT NULL OR -- if specific admin, show their stats regardless of role filter for this query
                'telecalling-owner-team' = ANY(adm.roles) OR
                'telecalling-tenant-team' = ANY(adm.roles) OR
                'super-admin' = ANY(adm.roles)
              )
    ),
    -- For assigned_in_period, we'd need an audit log of assignments.
    -- Approximating by tickets currently assigned to them that were created/updated recently. This is not ideal.
    -- Let's count tickets where their assignment was the *last* significant update in the period leading to an assigned state.
    -- This is still tricky without a proper assignment log.
    -- For now, this will be simplified to: Tickets they currently hold that moved to an assigned state in period.

    tickets_resolved AS (
        -- Tickets moved to RESOLVED by this admin (need audit log for who resolved it)
        -- Assuming assigned_support_admin_id is the one who resolves.
        SELECT
            t.assigned_support_admin_id AS resolver_admin_id,
            COUNT(t.ticket_id) AS resolved_count,
            AVG(EXTRACT(EPOCH FROM (t.resolved_at - t.created_at))/3600.0) AS avg_res_time -- From creation to resolution
        FROM public.tickets t
        WHERE t.status = 'RESOLVED'
          AND t.resolved_at >= p_start_date AND t.resolved_at <= p_end_date
          AND t.assigned_support_admin_id IS NOT NULL
        GROUP BY t.assigned_support_admin_id
    ),
    tickets_closed AS (
        -- Tickets moved to CLOSED by this admin (similar audit issue)
        SELECT
            t.assigned_support_admin_id AS closer_admin_id, -- Assuming assigned admin is closer
            COUNT(t.ticket_id) AS closed_count
        FROM public.tickets t
        WHERE t.status = 'CLOSED'
          AND t.closed_at >= p_start_date AND t.closed_at <= p_end_date
          AND t.assigned_support_admin_id IS NOT NULL
        GROUP BY t.assigned_support_admin_id
    ),
    -- A better 'tickets_assigned_in_period' would require an audit table like:
    -- ticket_assignments_log(ticket_id, assigned_to_admin_id, assigned_at, assigned_by_admin_id)
    -- For now, count currently assigned tickets to them:
    current_assigned_tickets AS (
         SELECT t.assigned_support_admin_id as admin_id, count(t.ticket_id) as currently_assigned_count
         FROM public.tickets t
         WHERE t.assigned_support_admin_id IS NOT NULL
           AND t.status NOT IN ('RESOLVED', 'CLOSED', 'CANCELLED')
         GROUP BY t.assigned_support_admin_id
    )
    SELECT
        ra.user_id AS admin_id,
        ra.name AS admin_name,
        ra.roles,
        COALESCE(cat.currently_assigned_count, 0) AS tickets_assigned_in_period, -- Placeholder for now
        COALESCE(tr.resolved_count, 0) AS tickets_resolved_in_period,
        COALESCE(tc.closed_count, 0) AS tickets_closed_in_period,
        ROUND(COALESCE(tr.avg_res_time, 0.0), 2) AS avg_resolution_time_hours
    FROM relevant_admins ra
    LEFT JOIN tickets_resolved tr ON ra.user_id = tr.resolver_admin_id
    LEFT JOIN tickets_closed tc ON ra.user_id = tc.closer_admin_id
    LEFT JOIN current_assigned_tickets cat ON ra.user_id = cat.admin_id
    ORDER BY admin_name;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_ticket_handling_performance_admin(DATE, DATE, UUID, public.admin_role_enum) TO authenticated;