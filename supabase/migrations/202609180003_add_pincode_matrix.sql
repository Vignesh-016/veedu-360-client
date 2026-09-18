CREATE TABLE IF NOT EXISTS public.management_service_pincodes (
  pincode INTEGER PRIMARY KEY CHECK (pincode BETWEEN 100000 AND 999999),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

INSERT INTO public.management_service_pincodes(pincode)
SELECT DISTINCT pincode FROM public.management_plan_pincodes
ON CONFLICT (pincode) DO NOTHING;

ALTER TABLE public.management_service_pincodes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS management_service_pincodes_admin_all ON public.management_service_pincodes;
CREATE POLICY management_service_pincodes_admin_all ON public.management_service_pincodes
  FOR ALL TO authenticated USING (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin'))
  WITH CHECK (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin'));

CREATE OR REPLACE FUNCTION public.list_management_pincode_matrix_admin()
RETURNS TABLE(pincode INTEGER, plan_id UUID)
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
  SELECT sp.pincode, mpp.plan_id
  FROM public.management_service_pincodes sp
  LEFT JOIN public.management_plan_pincodes mpp ON mpp.pincode=sp.pincode
  WHERE public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')
  ORDER BY sp.pincode, mpp.plan_id;
$$;

CREATE OR REPLACE FUNCTION public.bulk_add_management_service_pincodes_admin(p_pincodes INTEGER[])
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_count INTEGER;
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF EXISTS (SELECT 1 FROM unnest(COALESCE(p_pincodes, ARRAY[]::INTEGER[])) p WHERE p < 100000 OR p > 999999) THEN RAISE EXCEPTION 'All pincodes must be six digits'; END IF;
  INSERT INTO public.management_service_pincodes(pincode, created_by)
  SELECT DISTINCT p, auth.uid() FROM unnest(COALESCE(p_pincodes, ARRAY[]::INTEGER[])) p ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;

CREATE OR REPLACE FUNCTION public.toggle_management_pincode_plan_admin(p_pincode INTEGER, p_plan_id UUID, p_enabled BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.management_service_pincodes WHERE pincode=p_pincode) THEN RAISE EXCEPTION 'Pincode not found'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.management_service_plans WHERE plan_id=p_plan_id AND is_active=TRUE) THEN RAISE EXCEPTION 'Plan not found or inactive'; END IF;
  IF p_enabled THEN INSERT INTO public.management_plan_pincodes(plan_id,pincode,created_by) VALUES(p_plan_id,p_pincode,auth.uid()) ON CONFLICT DO NOTHING;
  ELSE DELETE FROM public.management_plan_pincodes WHERE plan_id=p_plan_id AND pincode=p_pincode;
  END IF;
END; $$;

GRANT EXECUTE ON FUNCTION public.list_management_pincode_matrix_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.bulk_add_management_service_pincodes_admin(INTEGER[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_management_pincode_plan_admin(INTEGER, UUID, BOOLEAN) TO authenticated;
