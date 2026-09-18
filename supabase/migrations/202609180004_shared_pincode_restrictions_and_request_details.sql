ALTER TABLE public.management_plan_access_requests
  ADD COLUMN IF NOT EXISTS property_details JSONB NOT NULL DEFAULT '{}'::jsonb;

DROP FUNCTION IF EXISTS public.request_management_plan_access_customer(INTEGER, UUID[]);
CREATE FUNCTION public.request_management_plan_access_customer(p_pincode INTEGER, p_plan_ids UUID[], p_property_details JSONB DEFAULT '{}'::jsonb)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication is required'; END IF;
  IF p_pincode IS NULL OR p_pincode < 100000 OR p_pincode > 999999 THEN RAISE EXCEPTION 'Invalid pincode'; END IF;
  IF COALESCE(array_length(p_plan_ids, 1), 0) = 0 THEN RAISE EXCEPTION 'Select at least one plan'; END IF;
  INSERT INTO public.management_plan_access_requests(requester_user_id, pincode, requested_plan_ids, property_details)
  VALUES (auth.uid(), p_pincode, p_plan_ids, COALESCE(p_property_details, '{}'::jsonb))
  ON CONFLICT (requester_user_id, pincode) WHERE status = 'PENDING'
  DO UPDATE SET requested_plan_ids = EXCLUDED.requested_plan_ids, property_details = EXCLUDED.property_details
  RETURNING request_id INTO v_id;
  RETURN v_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.request_management_plan_access_customer(INTEGER, UUID[], JSONB) TO authenticated;

CREATE OR REPLACE FUNCTION public.management_plan_pincode_allowed(p_plan_id UUID, p_pincode INTEGER)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE SET search_path=public AS $$
  SELECT CASE
    WHEN COALESCE(msp.document_processing_fee_enabled, FALSE) = FALSE OR COALESCE(msp.post_price, 0) <= 0 THEN TRUE
    WHEN NOT COALESCE(msp.requires_pincode, FALSE) THEN TRUE
    ELSE EXISTS (SELECT 1 FROM public.management_service_pincodes sp WHERE sp.pincode = p_pincode)
  END
  FROM public.management_service_plans msp WHERE msp.plan_id=p_plan_id AND msp.is_active=TRUE;
$$;

CREATE OR REPLACE FUNCTION public.validate_management_plan_pincode()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_requires BOOLEAN; v_fee_enabled BOOLEAN; v_fee NUMERIC;
BEGIN
  SELECT COALESCE(requires_pincode,FALSE), COALESCE(document_processing_fee_enabled,FALSE), COALESCE(post_price,0)
    INTO v_requires, v_fee_enabled, v_fee FROM public.management_service_plans WHERE plan_id=NEW.management_plan_id;
  IF NEW.management_plan_id IS NOT NULL
     AND NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin'))
     AND v_fee_enabled AND v_fee > 0 AND v_requires
     AND NOT EXISTS (SELECT 1 FROM public.management_service_pincodes sp WHERE sp.pincode=NEW.pincode)
  THEN RAISE EXCEPTION 'The selected paid management plan is not available for this property pincode.'; END IF;
  RETURN NEW;
END; $$;

DROP FUNCTION IF EXISTS public.list_management_plan_access_requests_admin();
CREATE FUNCTION public.list_management_plan_access_requests_admin()
RETURNS TABLE(request_id UUID, requester_user_id UUID, pincode INTEGER, requested_plan_ids UUID[], status TEXT, admin_notes TEXT, property_details JSONB, owner_details JSONB, created_at TIMESTAMPTZ)
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
  SELECT r.request_id, r.requester_user_id, r.pincode, r.requested_plan_ids, r.status, r.admin_notes, r.property_details,
    jsonb_build_object(
      'full_name', NULLIF(COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name', ''), ''),
      'email', u.email,
      'phone', COALESCE(NULLIF(u.phone, ''), NULLIF(u.raw_user_meta_data->>'phone', '')),
      'address_line1', op.address_line1,
      'address_line2', op.address_line2,
      'city', op.city,
      'state', op.state,
      'pincode', op.pincode
    ),
    r.created_at
  FROM public.management_plan_access_requests r
  LEFT JOIN auth.users u ON u.id = r.requester_user_id
  LEFT JOIN public.owner_profiles op ON op.owner_user_id = r.requester_user_id
  WHERE public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')
  ORDER BY r.created_at DESC;
$$;
GRANT EXECUTE ON FUNCTION public.list_management_plan_access_requests_admin() TO authenticated;
