-- Explicit plan ordering. Paid cards always appear before free cards.
ALTER TABLE public.management_service_plans
    ADD COLUMN IF NOT EXISTS display_order INTEGER;

WITH ordered AS (
    SELECT plan_id, row_number() OVER (
        ORDER BY (COALESCE(post_price, 0) <= 0), created_at, name
    ) AS position
    FROM public.management_service_plans
)
UPDATE public.management_service_plans msp
   SET display_order = ordered.position
  FROM ordered
 WHERE msp.plan_id = ordered.plan_id
   AND msp.display_order IS NULL;

ALTER TABLE public.management_service_plans
    ALTER COLUMN display_order SET NOT NULL,
    ALTER COLUMN display_order SET DEFAULT 999999;

CREATE INDEX IF NOT EXISTS management_service_plans_display_order_idx
    ON public.management_service_plans (is_active, display_order);

CREATE OR REPLACE FUNCTION public.list_management_plans_ordered(p_is_active_filter BOOLEAN DEFAULT TRUE)
RETURNS TABLE (
    plan_id UUID, name TEXT, percentage NUMERIC, description TEXT, is_active BOOLEAN,
    created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ, post_price NUMERIC,
    document_processing_fee_enabled BOOLEAN, display_order INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication is required.';
    END IF;
    RETURN QUERY
    SELECT msp.plan_id, msp.name, msp.percentage, msp.description, msp.is_active,
           msp.created_at, msp.updated_at, COALESCE(msp.post_price, 0),
           COALESCE(msp.document_processing_fee_enabled, FALSE), msp.display_order
      FROM public.management_service_plans msp
     WHERE p_is_active_filter IS NULL OR msp.is_active = p_is_active_filter
     ORDER BY (COALESCE(msp.post_price, 0) <= 0), msp.display_order, msp.created_at, msp.name;
END;
$$;

CREATE OR REPLACE FUNCTION public.move_management_plan_admin(p_plan_id UUID, p_direction TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current_order INTEGER;
    v_target_id UUID;
    v_target_order INTEGER;
    v_is_free BOOLEAN;
BEGIN
    IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
        RAISE EXCEPTION 'Unauthorized: insufficient privileges to reorder management plans.';
    END IF;
    IF lower(p_direction) NOT IN ('up', 'down') THEN RAISE EXCEPTION 'Direction must be up or down.'; END IF;

    SELECT display_order, COALESCE(post_price, 0) <= 0
      INTO v_current_order, v_is_free
      FROM public.management_service_plans
     WHERE plan_id = p_plan_id AND is_active = TRUE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Active management plan not found.'; END IF;

    IF lower(p_direction) = 'up' THEN
        SELECT plan_id, display_order INTO v_target_id, v_target_order
          FROM public.management_service_plans
         WHERE is_active = TRUE AND (COALESCE(post_price, 0) <= 0) = v_is_free
           AND display_order < v_current_order
         ORDER BY display_order DESC LIMIT 1;
    ELSE
        SELECT plan_id, display_order INTO v_target_id, v_target_order
          FROM public.management_service_plans
         WHERE is_active = TRUE AND (COALESCE(post_price, 0) <= 0) = v_is_free
           AND display_order > v_current_order
         ORDER BY display_order ASC LIMIT 1;
    END IF;

    IF v_target_id IS NULL THEN RETURN; END IF;
    UPDATE public.management_service_plans SET display_order = v_target_order WHERE plan_id = p_plan_id;
    UPDATE public.management_service_plans SET display_order = v_current_order WHERE plan_id = v_target_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_management_plans_ordered(BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.move_management_plan_admin(UUID, TEXT) TO authenticated;
NOTIFY pgrst, 'reload schema';
