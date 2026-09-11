ALTER TABLE public.management_service_plans
  ADD COLUMN IF NOT EXISTS strike_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD CONSTRAINT management_service_plans_strike_price_check CHECK (strike_price >= 0);

CREATE OR REPLACE FUNCTION public.update_management_plan_strike_price_admin(p_plan_id UUID,p_strike_price NUMERIC)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF NOT (public.current_user_has_role('accounts-team') OR public.current_user_has_role('super-admin')) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF p_strike_price IS NULL OR p_strike_price < 0 THEN RAISE EXCEPTION 'Invalid strike price'; END IF;
  UPDATE public.management_service_plans SET strike_price=p_strike_price,updated_at=NOW() WHERE plan_id=p_plan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Management plan not found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION public.update_management_plan_strike_price_admin(UUID,NUMERIC) TO authenticated;

DROP FUNCTION IF EXISTS public.list_management_plans_ordered(BOOLEAN);
CREATE FUNCTION public.list_management_plans_ordered(p_is_active_filter BOOLEAN DEFAULT TRUE)
RETURNS TABLE (plan_id UUID,name TEXT,percentage NUMERIC,description TEXT,is_active BOOLEAN,created_at TIMESTAMPTZ,updated_at TIMESTAMPTZ,post_price NUMERIC,document_processing_fee_enabled BOOLEAN,display_order INTEGER,requires_payout_account BOOLEAN,strike_price NUMERIC)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication is required.'; END IF;
 RETURN QUERY SELECT m.plan_id,m.name,m.percentage,m.description,m.is_active,m.created_at,m.updated_at,COALESCE(m.post_price,0),COALESCE(m.document_processing_fee_enabled,FALSE),m.display_order,COALESCE(m.requires_payout_account,FALSE),COALESCE(m.strike_price,0) FROM public.management_service_plans m WHERE p_is_active_filter IS NULL OR m.is_active=p_is_active_filter ORDER BY (COALESCE(m.post_price,0)<=0),m.display_order,m.created_at,m.name;
END; $$;
GRANT EXECUTE ON FUNCTION public.list_management_plans_ordered(BOOLEAN) TO authenticated;
NOTIFY pgrst,'reload schema';
