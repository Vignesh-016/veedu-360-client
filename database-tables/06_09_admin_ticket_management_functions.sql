-- FILE NAME: 06_09_admin_ticket_management_functions.sql
-- Description: Functions for admins (Telecalling Teams, Super Admin) to manage support tickets.
-------------------------------------------------------------------------------

-- Function for admins to list tickets with extensive filters
CREATE OR REPLACE FUNCTION public.list_tickets_admin(
    p_property_id_filter UUID DEFAULT NULL,
    p_raised_by_user_id_filter UUID DEFAULT NULL,
    p_assigned_support_admin_id_filter UUID DEFAULT NULL,
    p_assigned_to_vendor_id_filter UUID DEFAULT NULL,
    p_status_filter public.ticket_status_enum[] DEFAULT NULL,
    p_priority_filter public.ticket_priority_enum[] DEFAULT NULL,
    p_category_filter public.ticket_category_enum[] DEFAULT NULL,
    p_created_at_start TIMESTAMPTZ DEFAULT NULL,
    p_created_at_end TIMESTAMPTZ DEFAULT NULL,
    p_search_term TEXT DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    ticket_id BIGINT,
    subject TEXT,
    property_id UUID,
    property_address TEXT,
    property_locality TEXT,
    raised_by_user_id UUID,
    raiser_name TEXT,
    raiser_email TEXT,
    raiser_phone TEXT,
    category public.ticket_category_enum,
    priority public.ticket_priority_enum,
    status public.ticket_status_enum,
    assigned_support_admin_id UUID,
    assigned_support_admin_name TEXT,
    assigned_to_vendor_id UUID,
    assigned_vendor_name TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR
            public.current_user_has_role('telecalling-tenant-team') OR
            public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to list all tickets.';
    END IF;

    RETURN QUERY
    WITH tickets_base AS (
        SELECT
            t.ticket_id, t.subject, t.property_id, p.address AS prop_addr, p.locality AS prop_loc,
            t.raised_by_user_id AS raiser_id, raiser_user.raw_user_meta_data->>'full_name' AS r_name, raiser_user.email::TEXT AS r_email,
            raiser_user.phone::TEXT AS r_phone,
            t.category, t.priority, t.status,
            t.assigned_support_admin_id AS support_admin_id, support_admin_user.raw_user_meta_data->>'full_name' AS support_admin_name_val,
            t.assigned_to_vendor_id AS vendor_id, v.company_name AS vendor_name_val,
            t.created_at, t.updated_at, t.resolved_at, t.closed_at
        FROM public.tickets t
        JOIN public.properties p ON t.property_id = p.property_id
        JOIN auth.users raiser_user ON t.raised_by_user_id = raiser_user.id
        LEFT JOIN public.admins support_admin ON t.assigned_support_admin_id = support_admin.user_id
        LEFT JOIN auth.users support_admin_user ON support_admin.user_id = support_admin_user.id
        LEFT JOIN public.vendors v ON t.assigned_to_vendor_id = v.vendor_id
        WHERE (p_property_id_filter IS NULL OR t.property_id = p_property_id_filter)
          AND (p_raised_by_user_id_filter IS NULL OR t.raised_by_user_id = p_raised_by_user_id_filter)
          AND (p_assigned_support_admin_id_filter IS NULL OR t.assigned_support_admin_id = p_assigned_support_admin_id_filter)
          AND (p_assigned_to_vendor_id_filter IS NULL OR t.assigned_to_vendor_id = p_assigned_to_vendor_id_filter)
          AND (p_status_filter IS NULL OR t.status = ANY(p_status_filter))
          AND (p_priority_filter IS NULL OR t.priority = ANY(p_priority_filter))
          AND (p_category_filter IS NULL OR t.category = ANY(p_category_filter))
          AND (p_created_at_start IS NULL OR t.created_at >= p_created_at_start)
          AND (p_created_at_end IS NULL OR t.created_at <= p_created_at_end)
          AND (p_search_term IS NULL OR (
                t.subject ILIKE '%' || p_search_term || '%' OR
                t.description ILIKE '%' || p_search_term || '%' OR
                p.address ILIKE '%' || p_search_term || '%' OR
                p.locality ILIKE '%' || p_search_term || '%' OR
                raiser_user.raw_user_meta_data->>'full_name' ILIKE '%' || p_search_term || '%' OR
                raiser_user.email ILIKE '%' || p_search_term || '%' OR
                raiser_user.phone ILIKE '%' || p_search_term || '%' OR
                support_admin_user.raw_user_meta_data->>'full_name' ILIKE '%' || p_search_term || '%' OR
                v.company_name ILIKE '%' || p_search_term || '%' OR
                t.ticket_id::TEXT ILIKE '%' || p_search_term || '%'
              ))
    ),
    tickets_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM tickets_base
    )
    SELECT
        twc.ticket_id,
        twc.subject,
        twc.property_id,
        twc.prop_addr,
        twc.prop_loc,
        twc.raiser_id,
        twc.r_name,
        twc.r_email,
        twc.r_phone,
        twc.category,
        twc.priority,
        twc.status,
        twc.support_admin_id,
        twc.support_admin_name_val,
        twc.vendor_id,
        twc.vendor_name_val,
        twc.created_at,
        twc.updated_at,
        twc.resolved_at,
        twc.closed_at,
        twc.total_rows
    FROM tickets_with_count twc
    ORDER BY twc.updated_at DESC, twc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_tickets_admin(UUID, UUID, UUID, UUID, public.ticket_status_enum[], public.ticket_priority_enum[], public.ticket_category_enum[], TIMESTAMPTZ, TIMESTAMPTZ, TEXT, INTEGER, INTEGER) TO authenticated;

-- Function for admins to get full details of a specific ticket
CREATE OR REPLACE FUNCTION public.get_ticket_details_admin(p_ticket_id_input BIGINT)
RETURNS TABLE (
    ticket_id BIGINT, subject TEXT, description TEXT,
    property_id UUID, property_address TEXT, property_locality TEXT,
    raised_by_user_id UUID, raiser_name TEXT, raiser_email TEXT, raiser_phone TEXT,
    category public.ticket_category_enum, priority public.ticket_priority_enum, status public.ticket_status_enum,
    assigned_support_admin_id UUID, assigned_support_admin_name TEXT,
    assigned_to_vendor_id UUID, assigned_vendor_name TEXT, assigned_vendor_phone TEXT,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ, resolved_at TIMESTAMPTZ, closed_at TIMESTAMPTZ,
    images JSONB, -- Array of {image_id, image_url, description, uploaded_by_name, created_at}
    comments JSONB -- Array of {comment_id, user_id, user_name, user_is_admin, comment_text, is_internal, created_at}
) AS $$
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id_input, auth.uid()) THEN
         RAISE EXCEPTION 'Unauthorized: You do not have permission to view this ticket or ticket not found.';
    END IF;

    RETURN QUERY
    SELECT
        t.ticket_id, t.subject, t.description,
        t.property_id, p.address AS prop_addr, p.locality AS prop_loc,
        t.raised_by_user_id AS raiser_id, raiser_user.raw_user_meta_data->>'full_name' AS r_name, raiser_user.email::TEXT AS r_email, raiser_user.phone::TEXT AS r_phone,
        t.category, t.priority, t.status,
        t.assigned_support_admin_id AS support_admin_id, support_admin_auth_user.raw_user_meta_data->>'full_name' AS support_admin_name_val,
        t.assigned_to_vendor_id AS vendor_id, v.company_name AS vendor_name_val, v.phone::TEXT AS vendor_phone_val,
        t.resolution_notes,
        t.created_at, t.updated_at, t.resolved_at, t.closed_at,
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'image_id', ti.image_id, 'image_url', ti.image_url, 'description', ti.description,
                'uploaded_by_name', img_uploader_user.raw_user_meta_data->>'full_name',
                'created_at', ti.created_at
            ) ORDER BY ti.created_at ASC)
            FROM public.ticket_images ti
            JOIN auth.users img_uploader_user ON ti.uploaded_by = img_uploader_user.id
            WHERE ti.ticket_id = t.ticket_id
        ), '[]'::jsonb) AS images_data,
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'comment_id', tc.comment_id,
                'user_id', tc.user_id,
                'user_name', commenter_user.raw_user_meta_data->>'full_name',
                'user_is_admin', EXISTS(SELECT 1 FROM public.admins commenter_admin WHERE commenter_admin.user_id = tc.user_id),
                'comment_text', tc.comment_text,
                'is_internal', tc.is_internal,
                'created_at', tc.created_at
            ) ORDER BY tc.created_at ASC)
            FROM public.ticket_comments tc
            JOIN auth.users commenter_user ON tc.user_id = commenter_user.id
            WHERE tc.ticket_id = t.ticket_id
        ), '[]'::jsonb) AS comments_data
    FROM public.tickets t
    JOIN public.properties p ON t.property_id = p.property_id
    JOIN auth.users raiser_user ON t.raised_by_user_id = raiser_user.id
    LEFT JOIN public.admins support_admin ON t.assigned_support_admin_id = support_admin.user_id
    LEFT JOIN auth.users support_admin_auth_user ON support_admin.user_id = support_admin_auth_user.id
    LEFT JOIN public.vendors v ON t.assigned_to_vendor_id = v.vendor_id
    WHERE t.ticket_id = p_ticket_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_ticket_details_admin(BIGINT) TO authenticated;


-- Function for admins to update a ticket's core details
CREATE OR REPLACE FUNCTION public.update_ticket_details_admin(
    p_ticket_id BIGINT,
    p_subject TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_category public.ticket_category_enum DEFAULT NULL,
    p_priority public.ticket_priority_enum DEFAULT NULL,
    p_status public.ticket_status_enum DEFAULT NULL,
    p_resolution_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_can_update BOOLEAN := FALSE;
    v_calling_admin_id UUID := auth.uid();
    v_ticket_current_assignee UUID;
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, v_calling_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to update this ticket or ticket not found.';
    END IF;

    SELECT assigned_support_admin_id INTO v_ticket_current_assignee FROM public.tickets WHERE ticket_id = p_ticket_id;

    IF public.current_user_has_role('super-admin') OR
       (public.current_user_has_role('telecalling-owner-team') AND (v_ticket_current_assignee IS NULL OR v_ticket_current_assignee = v_calling_admin_id)) OR
       (public.current_user_has_role('telecalling-tenant-team') AND (v_ticket_current_assignee IS NULL OR v_ticket_current_assignee = v_calling_admin_id)) THEN
        v_can_update := TRUE;
    END IF;

    IF NOT v_can_update THEN
        RAISE EXCEPTION 'Unauthorized: You can only update unassigned tickets or tickets assigned to you, unless you are a super-admin.';
    END IF;

    UPDATE public.tickets
    SET subject = COALESCE(p_subject, subject),
        description = COALESCE(p_description, description),
        category = COALESCE(p_category, category),
        priority = COALESCE(p_priority, priority),
        status = COALESCE(p_status, status), 
        resolution_notes = COALESCE(p_resolution_notes, resolution_notes),
        updated_at = CURRENT_TIMESTAMP
    WHERE ticket_id = p_ticket_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Ticket ID % not found (should not happen after access check).', p_ticket_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_ticket_details_admin(BIGINT, TEXT, TEXT, public.ticket_category_enum, public.ticket_priority_enum, public.ticket_status_enum, TEXT) TO authenticated;

-- Function for telecalling teams or super-admin to assign a ticket to themselves or another admin
CREATE OR REPLACE FUNCTION public.assign_ticket_admin(
    p_ticket_id BIGINT,
    p_target_admin_id UUID 
) RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, v_calling_admin_id) THEN
         RAISE EXCEPTION 'Unauthorized: You do not have permission to manage this ticket or ticket not found.';
    END IF;

    IF v_calling_admin_id <> p_target_admin_id AND NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can assign tickets to other admins.';
    END IF;

    IF NOT (public.user_is_admin_with_role(p_target_admin_id, 'telecalling-owner-team') OR
            public.user_is_admin_with_role(p_target_admin_id, 'telecalling-tenant-team') OR
            public.user_is_admin_with_role(p_target_admin_id, 'super-admin')) THEN
        RAISE EXCEPTION 'Target admin % does not have a required role to be assigned a ticket.', p_target_admin_id;
    END IF;

    UPDATE public.tickets
    SET assigned_support_admin_id = p_target_admin_id,
        assigned_to_vendor_id = NULL, 
        status = CASE WHEN status = 'NEW' THEN 'OPEN' ELSE status END, 
        updated_at = CURRENT_TIMESTAMP
    WHERE ticket_id = p_ticket_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Ticket ID % not found.', p_ticket_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_ticket_admin(BIGINT, UUID) TO authenticated;


-- Function for admins to assign a ticket to a vendor
CREATE OR REPLACE FUNCTION public.assign_ticket_to_vendor_admin(
    p_ticket_id BIGINT,
    p_vendor_id UUID
) RETURNS VOID AS $$
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, auth.uid()) THEN
         RAISE EXCEPTION 'Unauthorized: You do not have permission to manage this ticket or ticket not found.';
    END IF;
    IF NOT (public.current_user_has_role('super-admin') OR public.current_user_has_role('telecalling-owner-team') OR public.current_user_has_role('telecalling-tenant-team')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to assign tickets to vendors.';
    END IF;


    IF NOT EXISTS (SELECT 1 FROM public.vendors WHERE vendor_id = p_vendor_id) THEN
        RAISE EXCEPTION 'Vendor ID % does not exist.', p_vendor_id;
    END IF;

    UPDATE public.tickets
    SET assigned_to_vendor_id = p_vendor_id,
        assigned_support_admin_id = NULL, 
        status = 'ASSIGNED', 
        updated_at = CURRENT_TIMESTAMP
    WHERE ticket_id = p_ticket_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Ticket ID % not found.', p_ticket_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.assign_ticket_to_vendor_admin(BIGINT, UUID) TO authenticated;


-- Function for admins to unassign a ticket (clears both admin and vendor assignment)
CREATE OR REPLACE FUNCTION public.unassign_ticket_admin(p_ticket_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_can_unassign BOOLEAN := FALSE;
    v_calling_admin_id UUID := auth.uid();
    v_ticket_current_assignee UUID;
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, v_calling_admin_id) THEN
         RAISE EXCEPTION 'Unauthorized: You do not have permission to manage this ticket or ticket not found.';
    END IF;

    SELECT assigned_support_admin_id INTO v_ticket_current_assignee FROM public.tickets WHERE ticket_id = p_ticket_id;

    IF public.current_user_has_role('super-admin') OR v_ticket_current_assignee = v_calling_admin_id THEN
        v_can_unassign := TRUE;
    END IF;

    IF NOT v_can_unassign THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins or the currently assigned admin can unassign this ticket.';
    END IF;

    UPDATE public.tickets
    SET assigned_support_admin_id = NULL,
        assigned_to_vendor_id = NULL,
        status = CASE WHEN status NOT IN ('NEW', 'RESOLVED', 'CLOSED', 'CANCELLED') THEN 'OPEN' ELSE status END, 
        updated_at = CURRENT_TIMESTAMP
    WHERE ticket_id = p_ticket_id;

    IF NOT FOUND THEN RAISE EXCEPTION 'Ticket ID % not found.', p_ticket_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.unassign_ticket_admin(BIGINT) TO authenticated;

-- Function for admins to add a comment to a ticket (can be internal)
CREATE OR REPLACE FUNCTION public.add_ticket_comment_admin(
    p_ticket_id BIGINT,
    p_comment_text TEXT,
    p_is_internal BOOLEAN DEFAULT FALSE
) RETURNS VOID AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, v_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to comment on this ticket or ticket not found.';
    END IF;

    IF p_comment_text IS NULL OR TRIM(p_comment_text) = '' THEN
        RAISE EXCEPTION 'Comment text cannot be empty.';
    END IF;

    INSERT INTO public.ticket_comments (ticket_id, user_id, comment_text, is_internal)
    VALUES (p_ticket_id, v_admin_id, p_comment_text, p_is_internal);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.add_ticket_comment_admin(BIGINT, TEXT, BOOLEAN) TO authenticated;

-- Function for admins to delete a ticket comment they made or any if super-admin
CREATE OR REPLACE FUNCTION public.delete_ticket_comment_admin(p_comment_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_comment_user_id UUID;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    SELECT user_id INTO v_comment_user_id FROM public.ticket_comments WHERE comment_id = p_comment_id;
    IF NOT FOUND THEN
        RAISE WARNING 'Ticket comment ID % not found.', p_comment_id;
        RETURN;
    END IF;

    IF NOT (public.current_user_has_role('super-admin') OR v_comment_user_id = auth.uid()) THEN
        RAISE EXCEPTION 'Unauthorized: Can only delete own comments or if super-admin.';
    END IF;

    DELETE FROM public.ticket_comments WHERE comment_id = p_comment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_ticket_comment_admin(BIGINT) TO authenticated;

-- Function for admins to delete a ticket image
CREATE OR REPLACE FUNCTION public.delete_ticket_image_admin(p_image_id UUID)
RETURNS VOID AS $$
DECLARE
    v_ticket_id BIGINT;
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    SELECT ticket_id INTO v_ticket_id FROM public.ticket_images WHERE image_id = p_image_id;
    IF NOT FOUND THEN
        RAISE WARNING 'Ticket image ID % not found.', p_image_id;
        RETURN;
    END IF;

    IF NOT public.check_user_can_access_ticket(v_ticket_id, auth.uid()) THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to manage images for this ticket.';
    END IF;

    DELETE FROM public.ticket_images WHERE image_id = p_image_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.delete_ticket_image_admin(UUID) TO authenticated;

-- Function for admins to record a ticket image upload
CREATE OR REPLACE FUNCTION public.record_ticket_image_upload_admin(
    p_ticket_id BIGINT,
    p_image_url TEXT,
    p_description TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_image_id UUID;
    v_uploader_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.check_user_can_access_ticket(p_ticket_id, v_uploader_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: You do not have permission to upload images for this ticket or ticket not found.';
    END IF;

    INSERT INTO public.ticket_images (ticket_id, uploaded_by, image_url, description)
    VALUES (p_ticket_id, v_uploader_admin_id, p_image_url, p_description)
    RETURNING image_id INTO v_image_id;

    RETURN v_image_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.record_ticket_image_upload_admin(BIGINT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.assign_ticket_to_self_telecaller(
    p_ticket_id BIGINT
) RETURNS VOID AS $$
DECLARE
    v_calling_admin_id UUID := auth.uid();
BEGIN
    IF NOT (public.current_user_has_role('telecalling-owner-team') OR
            public.current_user_has_role('telecalling-tenant-team') OR
            public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Only telecalling teams or super-admins can assign tickets to themselves.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.tickets t
        WHERE t.ticket_id = p_ticket_id
          AND t.assigned_support_admin_id IS NULL
          AND t.assigned_to_vendor_id IS NULL 
          AND t.status NOT IN ('RESOLVED', 'CLOSED', 'CANCELLED')
    ) THEN
        RAISE EXCEPTION 'Ticket ID % not found, is already assigned, or is in a final state (Resolved, Closed, Cancelled).', p_ticket_id;
    END IF;

    UPDATE public.tickets
    SET assigned_support_admin_id = v_calling_admin_id,
        status = CASE
                     WHEN status = 'NEW' THEN 'OPEN' 
                     ELSE status                         
                 END,
        updated_at = CURRENT_TIMESTAMP
    WHERE ticket_id = p_ticket_id
      AND assigned_support_admin_id IS NULL 
      AND assigned_to_vendor_id IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Failed to assign ticket %. It might have been assigned by another admin concurrently.', p_ticket_id;
    END IF;

    RAISE NOTICE 'Ticket % successfully assigned to admin %', p_ticket_id, v_calling_admin_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.assign_ticket_to_self_telecaller(BIGINT) TO authenticated;