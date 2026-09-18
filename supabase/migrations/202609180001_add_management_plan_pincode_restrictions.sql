ALTER TABLE public.management_service_plans
  ADD COLUMN IF NOT EXISTS requires_pincode BOOLEAN NOT NULL DEFAULT FALSE;

DROP FUNCTION IF EXISTS public.list_management_plans_ordered(BOOLEAN);
CREATE FUNCTION public.list_management_plans_ordered(p_is_active_filter BOOLEAN DEFAULT TRUE)
RETURNS TABLE (plan_id UUID,name TEXT,percentage NUMERIC,description TEXT,is_active BOOLEAN,created_at TIMESTAMPTZ,updated_at TIMESTAMPTZ,post_price NUMERIC,document_processing_fee_enabled BOOLEAN,display_order INTEGER,requires_payout_account BOOLEAN,strike_price NUMERIC,requires_pincode BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication is required.'; END IF;
 RETURN QUERY SELECT m.plan_id,m.name,m.percentage,m.description,m.is_active,m.created_at,m.updated_at,COALESCE(m.post_price,0),COALESCE(m.document_processing_fee_enabled,FALSE),m.display_order,COALESCE(m.requires_payout_account,FALSE),COALESCE(m.strike_price,0),COALESCE(m.requires_pincode,FALSE)
 FROM public.management_service_plans m
 WHERE p_is_active_filter IS NULL OR m.is_active=p_is_active_filter
 ORDER BY (COALESCE(m.post_price,0)<=0),m.display_order,m.created_at,m.name;
END; $$;
GRANT EXECUTE ON FUNCTION public.list_management_plans_ordered(BOOLEAN) TO authenticated;

CREATE TABLE IF NOT EXISTS public.management_plan_pincodes (
  plan_id UUID NOT NULL REFERENCES public.management_service_plans(plan_id) ON DELETE CASCADE,
  pincode INTEGER NOT NULL CHECK (pincode BETWEEN 100000 AND 999999),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  PRIMARY KEY (plan_id, pincode)
);

CREATE INDEX IF NOT EXISTS idx_management_plan_pincodes_pincode
  ON public.management_plan_pincodes(pincode);

ALTER TABLE public.management_plan_pincodes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS management_plan_pincodes_admin_all ON public.management_plan_pincodes;
CREATE POLICY management_plan_pincodes_admin_all ON public.management_plan_pincodes
  FOR ALL TO authenticated
  USING (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin'))
  WITH CHECK (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin'));

CREATE OR REPLACE FUNCTION public.update_management_plan_pincode_restriction_admin(
  p_plan_id UUID,
  p_requires_pincode BOOLEAN
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  UPDATE public.management_service_plans
  SET requires_pincode = COALESCE(p_requires_pincode, FALSE), updated_at = NOW()
  WHERE plan_id = p_plan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Management plan not found'; END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.replace_management_plan_pincodes_admin(
  p_plan_id UUID,
  p_pincodes INTEGER[]
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.management_service_plans WHERE plan_id = p_plan_id) THEN
    RAISE EXCEPTION 'Management plan not found';
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(COALESCE(p_pincodes, ARRAY[]::INTEGER[])) p WHERE p < 100000 OR p > 999999) THEN
    RAISE EXCEPTION 'Pincodes must be six digits';
  END IF;
  DELETE FROM public.management_plan_pincodes WHERE plan_id = p_plan_id;
  INSERT INTO public.management_plan_pincodes(plan_id, pincode, created_by)
  SELECT p_plan_id, p, auth.uid()
  FROM (SELECT DISTINCT unnest(COALESCE(p_pincodes, ARRAY[]::INTEGER[])) AS p) values_list;
END; $$;

CREATE OR REPLACE FUNCTION public.get_management_plan_pincodes_admin(p_plan_id UUID)
RETURNS TABLE(pincode INTEGER) LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
  SELECT mpp.pincode FROM public.management_plan_pincodes mpp
  WHERE mpp.plan_id = p_plan_id
    AND (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin'))
  ORDER BY mpp.pincode;
$$;

CREATE OR REPLACE FUNCTION public.list_management_pincode_rules_admin()
RETURNS TABLE(pincode INTEGER, plan_id UUID, plan_name TEXT)
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
  SELECT mpp.pincode, msp.plan_id, msp.name
  FROM public.management_plan_pincodes mpp
  JOIN public.management_service_plans msp ON msp.plan_id = mpp.plan_id
  WHERE public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')
  ORDER BY mpp.pincode, msp.name;
$$;

CREATE OR REPLACE FUNCTION public.replace_management_pincode_rule_admin(
  p_pincode INTEGER,
  p_plan_ids UUID[]
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF p_pincode IS NULL OR p_pincode < 100000 OR p_pincode > 999999 THEN
    RAISE EXCEPTION 'Pincode must be six digits';
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(COALESCE(p_plan_ids, ARRAY[]::UUID[])) plan_id
             WHERE NOT EXISTS (SELECT 1 FROM public.management_service_plans m WHERE m.plan_id = plan_id AND m.is_active = TRUE)) THEN
    RAISE EXCEPTION 'One or more selected plans are inactive or invalid';
  END IF;
  DELETE FROM public.management_plan_pincodes WHERE pincode = p_pincode;
  INSERT INTO public.management_plan_pincodes(plan_id, pincode, created_by)
  SELECT plan_id, p_pincode, auth.uid()
  FROM (SELECT DISTINCT unnest(COALESCE(p_plan_ids, ARRAY[]::UUID[])) AS plan_id) selected;
END; $$;

CREATE OR REPLACE FUNCTION public.management_plan_pincode_allowed(p_plan_id UUID, p_pincode INTEGER)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE SET search_path=public AS $$
  SELECT CASE
    WHEN NOT COALESCE(msp.requires_pincode, FALSE) THEN TRUE
    ELSE EXISTS (
      SELECT 1 FROM public.management_plan_pincodes mpp
      WHERE mpp.plan_id = p_plan_id AND mpp.pincode = p_pincode
    )
  END
  FROM public.management_service_plans msp
  WHERE msp.plan_id = p_plan_id AND msp.is_active = TRUE;
$$;

CREATE OR REPLACE FUNCTION public.validate_management_plan_pincode()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF NEW.management_plan_id IS NOT NULL
     AND NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin'))
     AND NOT COALESCE((SELECT requires_pincode FROM public.management_service_plans WHERE plan_id = NEW.management_plan_id), FALSE)
  THEN
    RETURN NEW;
  ELSIF NEW.management_plan_id IS NOT NULL
     AND NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin'))
     AND NOT EXISTS (
       SELECT 1 FROM public.management_plan_pincodes mpp
       WHERE mpp.plan_id = NEW.management_plan_id AND mpp.pincode = NEW.pincode
     )
  THEN
    RAISE EXCEPTION 'The selected management plan is not available for this property pincode.';
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_validate_management_plan_pincode ON public.properties;
CREATE TRIGGER trg_validate_management_plan_pincode
  BEFORE INSERT OR UPDATE OF management_plan_id, pincode ON public.properties
  FOR EACH ROW EXECUTE FUNCTION public.validate_management_plan_pincode();

GRANT EXECUTE ON FUNCTION public.update_management_plan_pincode_restriction_admin(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.replace_management_plan_pincodes_admin(UUID, INTEGER[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_management_plan_pincodes_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_management_pincode_rules_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.replace_management_pincode_rule_admin(INTEGER, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.management_plan_pincode_allowed(UUID, INTEGER) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
