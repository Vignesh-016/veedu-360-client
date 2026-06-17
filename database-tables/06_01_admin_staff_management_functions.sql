-- FILE NAME: 06_01_admin_staff_management_functions.sql
-- Description: Functions for super-admins to manage other admin staff.
-------------------------------------------------------------------------------

-- Function for super-admin to add a role to an admin staff member or create them
CREATE OR REPLACE FUNCTION public.add_admin_role(
    p_user_id UUID,
    p_role_to_add public.admin_role_enum
) RETURNS VOID AS $$
DECLARE
    v_existing_roles public.admin_role_enum[];
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can modify admin roles.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'User ID % not found in auth.users.', p_user_id;
    END IF;

    SELECT roles INTO v_existing_roles FROM public.admins WHERE user_id = p_user_id;

    IF v_existing_roles IS NULL THEN
        -- Admin doesn't exist, create them with this role
        INSERT INTO public.admins (user_id, roles, is_active)
        VALUES (p_user_id, ARRAY[p_role_to_add], TRUE);
    ELSE
        -- Admin exists, add role if not already present
        IF NOT (p_role_to_add = ANY(v_existing_roles)) THEN
            UPDATE public.admins
            SET roles = array_append(v_existing_roles, p_role_to_add),
                is_active = TRUE -- Ensure admin is active when a role is added
            WHERE user_id = p_user_id;
        ELSE
             -- If role already exists, ensure admin is active
            UPDATE public.admins SET is_active = TRUE WHERE user_id = p_user_id AND is_active = FALSE;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.add_admin_role(UUID, public.admin_role_enum) TO authenticated;

-- Function for super-admin to remove a role from an admin staff member
CREATE OR REPLACE FUNCTION public.remove_admin_role(
    p_user_id UUID,
    p_role_to_remove public.admin_role_enum
) RETURNS VOID AS $$
DECLARE
    v_current_roles public.admin_role_enum[];
    v_new_roles public.admin_role_enum[];
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can modify admin roles.';
    END IF;

    IF p_user_id = auth.uid() AND p_role_to_remove = 'super-admin' THEN
        RAISE EXCEPTION 'Super-admins cannot remove their own super-admin role.';
    END IF;

    SELECT roles INTO v_current_roles FROM public.admins WHERE user_id = p_user_id;

    IF v_current_roles IS NULL THEN
        RAISE WARNING 'Admin with User ID % not found.', p_user_id;
        RETURN;
    END IF;

    v_new_roles := array_remove(v_current_roles, p_role_to_remove);

    IF array_length(v_new_roles, 1) IS NULL OR array_length(v_new_roles, 1) = 0 THEN
        -- All roles removed, delete the admin record
        DELETE FROM public.admins WHERE user_id = p_user_id;
    ELSE
        UPDATE public.admins
        SET roles = v_new_roles
        WHERE user_id = p_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.remove_admin_role(UUID, public.admin_role_enum) TO authenticated;

-- Function for super-admin to set the exact list of roles for an admin staff member
CREATE OR REPLACE FUNCTION public.set_admin_roles(
    p_user_id UUID,
    p_roles public.admin_role_enum[]
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can set admin roles.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'User ID % not found in auth.users.', p_user_id;
    END IF;

    IF p_user_id = auth.uid() AND NOT ('super-admin' = ANY(COALESCE(p_roles, '{}'::public.admin_role_enum[]))) THEN
        RAISE EXCEPTION 'Super-admins cannot remove their own super-admin role by setting roles to an empty set or a set without super-admin.';
    END IF;

    IF p_roles IS NULL OR array_length(p_roles, 1) IS NULL OR array_length(p_roles, 1) = 0 THEN
        -- No roles provided, delete the admin record
        DELETE FROM public.admins WHERE user_id = p_user_id;
    ELSE
        INSERT INTO public.admins (user_id, roles, is_active)
        VALUES (p_user_id, p_roles, TRUE)
        ON CONFLICT (user_id) DO UPDATE
        SET roles = EXCLUDED.roles,
            is_active = TRUE; -- Ensure admin is active when roles are set/updated
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.set_admin_roles(UUID, public.admin_role_enum[]) TO authenticated;

-- Function for super-admin to update served pincodes for an admin
CREATE OR REPLACE FUNCTION public.update_admin_pincodes(
    p_user_id UUID,
    p_pincodes INTEGER[]
) RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can update pincodes.';
    END IF;

    UPDATE public.admins
    SET served_pincodes = p_pincodes
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE WARNING 'Admin with User ID % not found. Pincodes not updated.', p_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_admin_pincodes(UUID, INTEGER[]) TO authenticated;

-- Function for super-admin to activate an admin
CREATE OR REPLACE FUNCTION public.activate_admin(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can activate admins.';
    END IF;
    UPDATE public.admins SET is_active = TRUE WHERE user_id = p_user_id;
    IF NOT FOUND THEN RAISE WARNING 'Admin % not found for activation.', p_user_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.activate_admin(UUID) TO authenticated;

-- Function for super-admin to deactivate an admin
CREATE OR REPLACE FUNCTION public.deactivate_admin(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can deactivate admins.';
    END IF;
    IF p_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot deactivate your own admin account.';
    END IF;
    UPDATE public.admins SET is_active = FALSE WHERE user_id = p_user_id;
    IF NOT FOUND THEN RAISE WARNING 'Admin % not found for deactivation.', p_user_id; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.deactivate_admin(UUID) TO authenticated;

-- Function for super-admin to list admin staff members
CREATE OR REPLACE FUNCTION public.list_admins(
    p_role_filter public.admin_role_enum DEFAULT NULL,
    p_is_active_filter BOOLEAN DEFAULT NULL,
    p_search_term TEXT DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    user_id UUID,
    email TEXT,
    full_name TEXT,
    phone TEXT,
    roles public.admin_role_enum[],
    served_pincodes INTEGER[],
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can list admins.';
    END IF;

    RETURN QUERY
    WITH admin_users AS (
        SELECT
            a.user_id,
            u.email::TEXT,
            u.raw_user_meta_data->>'full_name' AS user_full_name,
            u.phone::TEXT,
            a.roles,
            a.served_pincodes,
            a.is_active,
            a.created_at,
            a.updated_at
        FROM public.admins a
        JOIN auth.users u ON a.user_id = u.id
        WHERE (p_role_filter IS NULL OR p_role_filter = ANY(a.roles))
          AND (p_is_active_filter IS NULL OR a.is_active = p_is_active_filter)
          AND (p_search_term IS NULL OR (
                u.email ILIKE '%' || p_search_term || '%' OR
                u.raw_user_meta_data->>'full_name' ILIKE '%' || p_search_term || '%' OR
                u.phone ILIKE '%' || p_search_term || '%' OR
                a.user_id::TEXT ILIKE '%' || p_search_term || '%'
              ))
    ),
    admins_with_count AS (
        SELECT *, COUNT(*) OVER() AS total_rows FROM admin_users
    )
    SELECT
        awc.user_id,
        awc.email,
        awc.user_full_name,
        awc.phone,
        awc.roles,
        awc.served_pincodes,
        awc.is_active,
        awc.created_at,
        awc.updated_at,
        awc.total_rows
    FROM admins_with_count awc
    ORDER BY awc.user_full_name ASC, awc.created_at DESC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_admins(public.admin_role_enum, BOOLEAN, TEXT, INTEGER, INTEGER) TO authenticated;


-- Function for super-admin to get details of a specific admin staff member
CREATE OR REPLACE FUNCTION public.get_admin_details(p_admin_user_id UUID)
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    full_name TEXT,
    phone TEXT,
    roles public.admin_role_enum[],
    served_pincodes INTEGER[],
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE, -- admin record created_at
    updated_at TIMESTAMP WITH TIME ZONE, -- admin record updated_at
    auth_user_created_at TIMESTAMP WITH TIME ZONE -- auth.users record created_at
) AS $$
BEGIN
    IF NOT public.current_user_has_role('super-admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only super-admins can view admin details.';
    END IF;

    RETURN QUERY
    SELECT
        a.user_id,
        u.email::TEXT,
        u.raw_user_meta_data->>'full_name' AS user_full_name,
        u.phone::TEXT,
        a.roles,
        a.served_pincodes,
        a.is_active,
        a.created_at,
        a.updated_at,
        u.created_at AS auth_user_created_at_val
    FROM public.admins a
    JOIN auth.users u ON a.user_id = u.id
    WHERE a.user_id = p_admin_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_admin_details(UUID) TO authenticated;


-- User-facing functions (formerly in admin_user_management) like get_customer_details_admin
-- will be moved to a more general admin function file or a customer-specific admin file,
-- as this file is now focused on *staff* (admins table) management.
-- For instance, `get_user_details_admin` would become `get_customer_full_details_admin` and
-- would be accessible by various admin roles, not just super-admin for staff management.