-- FILE NAME: 05_06_customer_ticket_management_functions.sql
-- Description: Functions for customers (tenants, landlords) to manage support tickets.
-------------------------------------------------------------------------------

-- Function for Customers (usually Tenants) to create a ticket
CREATE OR REPLACE FUNCTION public.create_ticket_customer(
    p_property_id UUID,
    p_subject TEXT,
    p_description TEXT,
    p_category public.ticket_category_enum,
    p_priority public.ticket_priority_enum DEFAULT 'MEDIUM'
) RETURNS BIGINT AS $$
DECLARE
    v_ticket_id BIGINT;
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- The check_ticket_raiser_is_tenant trigger (in 04_triggers.sql) will validate
    -- if the user is the tenant or owner of the property.
    -- This trigger needs to use `public.properties.tenant` and `public.properties.submitter`.

    INSERT INTO public.tickets (
        property_id, raised_by_user_id, subject, description, category, priority, status
    ) VALUES (
        p_property_id, v_user_id, p_subject, p_description, p_category, p_priority, 'NEW'
    ) RETURNING ticket_id INTO v_ticket_id;

    RETURN v_ticket_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_ticket_customer(UUID, TEXT, TEXT, public.ticket_category_enum, public.ticket_priority_enum) TO authenticated;

-- Function for Customers to list their own raised tickets
CREATE OR REPLACE FUNCTION public.get_my_raised_tickets_customer(
    p_status_filter public.ticket_status_enum[] DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    ticket_id BIGINT,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    subject TEXT,
    category public.ticket_category_enum,
    priority public.ticket_priority_enum,
    status public.ticket_status_enum,
    assigned_support_admin_name TEXT, -- Name of admin if assigned
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH my_tickets_base AS (
        SELECT
            t.ticket_id,
            t.property_id,
            p.address AS prop_address,
            p.locality AS prop_locality,
            p.city AS prop_city,
            t.subject,
            t.category,
            t.priority,
            t.status,
            assignee_auth_user.raw_user_meta_data->>'full_name' AS assignee_name,
            t.created_at,
            t.updated_at,
            t.resolved_at,
            t.closed_at
        FROM public.tickets t
        JOIN public.properties p ON t.property_id = p.property_id
        LEFT JOIN public.admins assignee_admin ON t.assigned_support_admin_id = assignee_admin.user_id
        LEFT JOIN auth.users assignee_auth_user ON assignee_admin.user_id = assignee_auth_user.id
        WHERE t.raised_by_user_id = v_current_user_id
          AND (p_status_filter IS NULL OR t.status = ANY(p_status_filter))
    ),
    tickets_with_count AS (
        SELECT *, COUNT(*) OVER() as total_rows FROM my_tickets_base
    )
    SELECT
        twc.ticket_id, twc.property_id, twc.prop_address, twc.prop_locality, twc.prop_city,
        twc.subject, twc.category, twc.priority, twc.status,
        twc.assignee_name,
        twc.created_at, twc.updated_at, twc.resolved_at, twc.closed_at,
        twc.total_rows
    FROM tickets_with_count twc
    ORDER BY twc.updated_at DESC, twc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_my_raised_tickets_customer(public.ticket_status_enum[], INTEGER, INTEGER) TO authenticated;


-- Function for Landlords (property submitters) to list tickets related to their properties
CREATE OR REPLACE FUNCTION public.get_property_tickets_landlord(
    p_property_id_filter UUID DEFAULT NULL,
    p_status_filter public.ticket_status_enum[] DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
    ticket_id BIGINT,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    subject TEXT,
    category public.ticket_category_enum,
    priority public.ticket_priority_enum,
    status public.ticket_status_enum,
    raised_by_user_id UUID,
    raiser_name TEXT,
    raiser_email TEXT,
    raiser_phone TEXT,
    assigned_support_admin_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    RETURN QUERY
    WITH landlord_tickets_base AS (
        SELECT
            t.ticket_id,
            t.property_id,
            p.address AS prop_address,
            p.locality AS prop_locality,
            p.city AS prop_city,
            t.subject,
            t.category,
            t.priority,
            t.status,
            t.raised_by_user_id,
            (raiser_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS raiser_name_val,
            raiser_auth_user.email::TEXT AS raiser_email_val,
            raiser_auth_user.phone::TEXT AS raiser_phone_val,
            assignee_auth_user.raw_user_meta_data->>'full_name' AS assignee_name,
            t.created_at,
            t.updated_at,
            t.resolved_at,
            t.closed_at
        FROM public.tickets t
        JOIN public.properties p ON t.property_id = p.property_id
        JOIN auth.users raiser_auth_user ON t.raised_by_user_id = raiser_auth_user.id
        LEFT JOIN public.admins assignee_admin ON t.assigned_support_admin_id = assignee_admin.user_id
        LEFT JOIN auth.users assignee_auth_user ON assignee_admin.user_id = assignee_auth_user.id
        WHERE p.submitter = v_current_user_id -- Property owner is the current user
          AND (p_property_id_filter IS NULL OR t.property_id = p_property_id_filter)
          AND (p_status_filter IS NULL OR t.status = ANY(p_status_filter))
    ),
    tickets_with_count AS (
        SELECT *, COUNT(*) OVER() as total_rows FROM landlord_tickets_base
    )
    SELECT
        twc.ticket_id, twc.property_id, twc.prop_address, twc.prop_locality, twc.prop_city,
        twc.subject, twc.category, twc.priority, twc.status,
        twc.raised_by_user_id, twc.raiser_name_val, twc.raiser_email_val, twc.raiser_phone_val,
        twc.assignee_name,
        twc.created_at, twc.updated_at, twc.resolved_at, twc.closed_at,
        twc.total_rows
    FROM tickets_with_count twc
    ORDER BY twc.updated_at DESC, twc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_property_tickets_landlord(UUID, public.ticket_status_enum[], INTEGER, INTEGER) TO authenticated;

-- Function for Customers (Tenant/Landlord) to get details of a specific ticket they can access
CREATE OR REPLACE FUNCTION public.get_ticket_details_customer(p_ticket_id_input BIGINT)
RETURNS TABLE (
    ticket_id BIGINT,
    subject TEXT,
    description TEXT,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    property_city TEXT,
    raised_by_user_id UUID,
    raiser_name TEXT,
    raiser_email TEXT,
    raiser_phone TEXT,
    category public.ticket_category_enum,
    priority public.ticket_priority_enum,
    status public.ticket_status_enum,
    assigned_support_admin_name TEXT,
    resolution_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE,
    images JSONB, -- Array of {image_id, image_url, description, uploaded_by_name, created_at}
    comments JSONB -- Array of {comment_id, user_id, user_name, comment_text, created_at} non-internal
) AS $$
DECLARE
    v_current_user_id UUID := auth.uid();
    v_can_access BOOLEAN;
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT public.check_user_can_access_ticket(p_ticket_id_input, v_current_user_id) INTO v_can_access;

    IF NOT v_can_access THEN
        RAISE EXCEPTION 'You do not have permission to view this ticket or ticket not found.';
    END IF;

    RETURN QUERY
    SELECT
        t.ticket_id, t.subject, t.description, t.property_id,
        p.address AS prop_address, p.locality AS prop_locality, p.city AS prop_city,
        t.raised_by_user_id,
        (raiser_auth_user.raw_user_meta_data ->> 'full_name')::TEXT AS raiser_name_val,
        raiser_auth_user.email::TEXT AS raiser_email_val,
        raiser_auth_user.phone::TEXT AS raiser_phone_val,
        t.category, t.priority, t.status,
        assignee_auth_user.raw_user_meta_data->>'full_name' AS assignee_name,
        t.resolution_notes,
        t.created_at, t.updated_at, t.resolved_at, t.closed_at,
        COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'image_id', ti.image_id,
                    'image_url', ti.image_url,
                    'description', ti.description,
                    'uploaded_by_name', (uploader_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                    'created_at', ti.created_at
                ) ORDER BY ti.created_at ASC
            )
            FROM public.ticket_images ti
            JOIN auth.users uploader_auth_user ON ti.uploaded_by = uploader_auth_user.id
            WHERE ti.ticket_id = t.ticket_id),
            '[]'::jsonb
        ) AS ticket_images_data,
        COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'comment_id', tc.comment_id,
                    'user_id', tc.user_id,
                    'user_name', (commenter_auth_user.raw_user_meta_data->>'full_name')::TEXT,
                    'comment_text', tc.comment_text,
                    'created_at', tc.created_at
                ) ORDER BY tc.created_at ASC
            )
            FROM public.ticket_comments tc
            JOIN auth.users commenter_auth_user ON tc.user_id = commenter_auth_user.id
            WHERE tc.ticket_id = t.ticket_id AND tc.is_internal = FALSE), -- Customers only see non-internal comments
            '[]'::jsonb
        ) AS ticket_comments_data
    FROM public.tickets t
    JOIN public.properties p ON t.property_id = p.property_id
    JOIN auth.users raiser_auth_user ON t.raised_by_user_id = raiser_auth_user.id
    LEFT JOIN public.admins assignee_admin ON t.assigned_support_admin_id = assignee_admin.user_id
    LEFT JOIN auth.users assignee_auth_user ON assignee_admin.user_id = assignee_auth_user.id
    WHERE t.ticket_id = p_ticket_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_ticket_details_customer(BIGINT) TO authenticated;

-- Function for Customers (Tenant/Landlord) to add a non-internal comment to a ticket they can access
CREATE OR REPLACE FUNCTION public.add_ticket_comment_customer(
    p_ticket_id_input BIGINT,
    p_comment_text TEXT
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_can_access BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT public.check_user_can_access_ticket(p_ticket_id_input, v_user_id) INTO v_can_access;

    IF NOT v_can_access THEN
        RAISE EXCEPTION 'You do not have permission to comment on this ticket or ticket not found.';
    END IF;

    IF p_comment_text IS NULL OR TRIM(p_comment_text) = '' THEN
        RAISE EXCEPTION 'Comment text cannot be empty.';
    END IF;

    INSERT INTO public.ticket_comments (ticket_id, user_id, comment_text, is_internal)
    VALUES (p_ticket_id_input, v_user_id, p_comment_text, FALSE); -- Customer comments are never internal
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.add_ticket_comment_customer(BIGINT, TEXT) TO authenticated;