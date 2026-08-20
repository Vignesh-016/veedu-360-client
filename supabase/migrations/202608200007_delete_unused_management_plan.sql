-- Keep property history intact: only plans with no associated property may be deleted.
CREATE OR REPLACE FUNCTION public.delete_unused_management_plan_admin(p_plan_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: insufficient privileges to delete management plans.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.properties WHERE management_plan_id = p_plan_id) THEN
        RAISE EXCEPTION 'This plan has been used by one or more properties and cannot be deleted. Deactivate it instead to preserve property history.';
    END IF;

    DELETE FROM public.management_service_plans WHERE plan_id = p_plan_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Management plan not found.';
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_unused_management_plan_admin(UUID) TO authenticated;
NOTIFY pgrst, 'reload schema';
