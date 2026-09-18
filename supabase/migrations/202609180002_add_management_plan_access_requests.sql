CREATE TABLE IF NOT EXISTS public.management_plan_access_requests (
  request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pincode INTEGER NOT NULL CHECK (pincode BETWEEN 100000 AND 999999),
  requested_plan_ids UUID[] NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED')),
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_one_pending_plan_access_request
  ON public.management_plan_access_requests(requester_user_id, pincode)
  WHERE status = 'PENDING';

ALTER TABLE public.management_plan_access_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS management_plan_access_requests_customer_insert ON public.management_plan_access_requests;
DROP POLICY IF EXISTS management_plan_access_requests_customer_read ON public.management_plan_access_requests;
DROP POLICY IF EXISTS management_plan_access_requests_admin_all ON public.management_plan_access_requests;
CREATE POLICY management_plan_access_requests_customer_insert ON public.management_plan_access_requests
  FOR INSERT TO authenticated WITH CHECK (requester_user_id = auth.uid());
CREATE POLICY management_plan_access_requests_customer_read ON public.management_plan_access_requests
  FOR SELECT TO authenticated USING (requester_user_id = auth.uid());
CREATE POLICY management_plan_access_requests_admin_all ON public.management_plan_access_requests
  FOR ALL TO authenticated USING (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin'))
  WITH CHECK (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin'));

CREATE OR REPLACE FUNCTION public.request_management_plan_access_customer(p_pincode INTEGER, p_plan_ids UUID[])
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication is required'; END IF;
  IF p_pincode IS NULL OR p_pincode < 100000 OR p_pincode > 999999 THEN RAISE EXCEPTION 'Invalid pincode'; END IF;
  IF COALESCE(array_length(p_plan_ids, 1), 0) = 0 THEN RAISE EXCEPTION 'Select at least one plan'; END IF;
  INSERT INTO public.management_plan_access_requests(requester_user_id, pincode, requested_plan_ids)
  VALUES (auth.uid(), p_pincode, p_plan_ids)
  ON CONFLICT (requester_user_id, pincode) WHERE status = 'PENDING'
  DO UPDATE SET requested_plan_ids = EXCLUDED.requested_plan_ids
  RETURNING request_id INTO v_id;
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_management_plan_access_requests_admin()
RETURNS TABLE(request_id UUID, requester_user_id UUID, pincode INTEGER, requested_plan_ids UUID[], status TEXT, admin_notes TEXT, created_at TIMESTAMPTZ, reviewed_at TIMESTAMPTZ)
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
  SELECT r.request_id, r.requester_user_id, r.pincode, r.requested_plan_ids, r.status, r.admin_notes, r.created_at, r.reviewed_at
  FROM public.management_plan_access_requests r
  WHERE public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')
  ORDER BY r.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION public.review_management_plan_access_request_admin(p_request_id UUID, p_status TEXT, p_admin_notes TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF p_status NOT IN ('APPROVED','REJECTED') THEN RAISE EXCEPTION 'Invalid request status'; END IF;
  UPDATE public.management_plan_access_requests SET status=p_status, admin_notes=p_admin_notes, reviewed_at=NOW(), reviewed_by=auth.uid() WHERE request_id=p_request_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Request not found'; END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.management_plan_pincode_allowed(p_plan_id UUID, p_pincode INTEGER)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE SET search_path=public AS $$
  SELECT CASE
    WHEN COALESCE(msp.document_processing_fee_enabled, FALSE) = FALSE OR COALESCE(msp.post_price, 0) <= 0 THEN TRUE
    WHEN NOT COALESCE(msp.requires_pincode, FALSE) THEN TRUE
    ELSE EXISTS (SELECT 1 FROM public.management_plan_pincodes mpp WHERE mpp.plan_id = p_plan_id AND mpp.pincode = p_pincode)
  END
  FROM public.management_service_plans msp WHERE msp.plan_id=p_plan_id AND msp.is_active=TRUE;
$$;

GRANT EXECUTE ON FUNCTION public.request_management_plan_access_customer(INTEGER, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_management_plan_access_requests_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_management_plan_access_request_admin(UUID, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.bulk_replace_management_pincode_rule_admin(p_pincodes INTEGER[], p_plan_id UUID)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_count INTEGER;
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.management_service_plans WHERE plan_id=p_plan_id AND is_active=TRUE) THEN RAISE EXCEPTION 'Selected plan is inactive or invalid'; END IF;
  IF EXISTS (SELECT 1 FROM unnest(COALESCE(p_pincodes, ARRAY[]::INTEGER[])) p WHERE p < 100000 OR p > 999999) THEN RAISE EXCEPTION 'All pincodes must be six digits'; END IF;
  INSERT INTO public.management_plan_pincodes(plan_id, pincode, created_by)
  SELECT p_plan_id, p, auth.uid() FROM (SELECT DISTINCT unnest(COALESCE(p_pincodes, ARRAY[]::INTEGER[])) p) input
  ON CONFLICT (plan_id, pincode) DO NOTHING;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;
GRANT EXECUTE ON FUNCTION public.bulk_replace_management_pincode_rule_admin(INTEGER[], UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.validate_management_plan_pincode()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_requires BOOLEAN; v_fee_enabled BOOLEAN; v_fee NUMERIC;
BEGIN
  SELECT COALESCE(requires_pincode,FALSE), COALESCE(document_processing_fee_enabled,FALSE), COALESCE(post_price,0)
    INTO v_requires, v_fee_enabled, v_fee FROM public.management_service_plans WHERE plan_id=NEW.management_plan_id;
  IF NEW.management_plan_id IS NOT NULL
     AND NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin'))
     AND v_fee_enabled AND v_fee > 0 AND v_requires
     AND NOT EXISTS (SELECT 1 FROM public.management_plan_pincodes mpp WHERE mpp.plan_id=NEW.management_plan_id AND mpp.pincode=NEW.pincode)
  THEN RAISE EXCEPTION 'The selected paid management plan is not available for this property pincode.'; END IF;
  RETURN NEW;
END; $$;
