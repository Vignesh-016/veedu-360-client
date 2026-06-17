-- FILE NAME: 06_10_admin_management_plan_functions.sql
-- Description: Functions for admins (primarily Accounts Team, Super Admin) to manage property management service plans.
-------------------------------------------------------------------------------

-- Function for admins to create a new management service plan
CREATE OR REPLACE FUNCTION public.create_management_plan_admin(
    p_name TEXT,
    p_percentage DECIMAL(5, 2), -- Percentage of rent/sale price, etc.
    p_description TEXT DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT TRUE
) RETURNS UUID AS $$
DECLARE
    v_plan_id UUID;
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to create management plans.';
    END IF;

    IF p_name IS NULL OR TRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Management plan name cannot be empty.';
    END IF;
    IF p_percentage IS NULL OR p_percentage < 0 OR p_percentage > 100 THEN
        RAISE EXCEPTION 'Percentage must be between 0 and 100.';
    END IF;

    INSERT INTO public.management_service_plans (name, percentage, description, is_active)
    VALUES (TRIM(p_name), p_percentage, p_description, p_is_active)
    RETURNING plan_id INTO v_plan_id;

    RETURN v_plan_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.create_management_plan_admin(TEXT, DECIMAL(5,2), TEXT, BOOLEAN) TO authenticated;

-- Function for admins to update an existing management service plan
CREATE OR REPLACE FUNCTION public.update_management_plan_admin(
    p_plan_id UUID,
    p_name TEXT DEFAULT NULL,
    p_percentage DECIMAL(5, 2) DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: Insufficient privileges to update management plans.';
    END IF;

    IF p_name IS NOT NULL AND TRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Management plan name cannot be empty if provided.';
    END IF;
    IF p_percentage IS NOT NULL AND (p_percentage < 0 OR p_percentage > 100) THEN
        RAISE EXCEPTION 'Percentage must be between 0 and 100 if provided.';
    END IF;

    UPDATE public.management_service_plans
    SET name = COALESCE(TRIM(p_name), name),
        percentage = COALESCE(p_percentage, percentage),
        description = COALESCE(p_description, description),
        is_active = COALESCE(p_is_active, is_active),
        updated_at = CURRENT_TIMESTAMP
    WHERE plan_id = p_plan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Management Service Plan with ID % not found.', p_plan_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.update_management_plan_admin(UUID, TEXT, DECIMAL(5,2), TEXT, BOOLEAN) TO authenticated;

-- Function for admins to list management service plans
CREATE OR REPLACE FUNCTION public.list_management_plans_admin(
    p_is_active_filter BOOLEAN DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_limit INTEGER DEFAULT 25
) RETURNS TABLE (
    plan_id UUID,
    name TEXT,
    percentage DECIMAL(5, 2),
    description TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    total_count BIGINT
) AS $$
BEGIN
    -- All admins might need to see these plans when associating with a property,
    -- but only Accounts/SuperAdmin can CRUD them.
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required to list management plans.';
    END IF;

    RETURN QUERY
    WITH plans_base AS (
      SELECT msp.*
      FROM public.management_service_plans msp
      WHERE (p_is_active_filter IS NULL OR msp.is_active = p_is_active_filter)
    ),
    plans_with_count AS (
      SELECT *, COUNT(*) OVER() as total_rows FROM plans_base
    )
    SELECT
        pwc.plan_id, pwc.name, pwc.percentage, pwc.description, pwc.is_active,
        pwc.created_at, pwc.updated_at, pwc.total_rows
    FROM plans_with_count pwc
    ORDER BY pwc.is_active DESC, pwc.percentage ASC, pwc.name ASC
    OFFSET p_offset
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.list_management_plans_admin(BOOLEAN, INTEGER, INTEGER) TO authenticated;


-- Function for admins to get details of a specific management service plan
CREATE OR REPLACE FUNCTION public.get_management_plan_details_admin(p_plan_id_input UUID)
RETURNS TABLE (
    plan_id UUID,
    name TEXT,
    percentage DECIMAL(5, 2),
    description TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    IF NOT public.current_user_is_admin() THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required.';
    END IF;

    RETURN QUERY
    SELECT msp.*
    FROM public.management_service_plans msp
    WHERE msp.plan_id = p_plan_id_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
GRANT EXECUTE ON FUNCTION public.get_management_plan_details_admin(UUID) TO authenticated;
