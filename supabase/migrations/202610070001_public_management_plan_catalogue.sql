-- Active management plans are public catalogue data; posting still requires auth.
CREATE OR REPLACE FUNCTION public.list_management_plans_ordered(p_is_active_filter BOOLEAN DEFAULT TRUE)
RETURNS TABLE (plan_id UUID,name TEXT,percentage NUMERIC,description TEXT,is_active BOOLEAN,created_at TIMESTAMPTZ,updated_at TIMESTAMPTZ,post_price NUMERIC,document_processing_fee_enabled BOOLEAN,display_order INTEGER,requires_payout_account BOOLEAN,strike_price NUMERIC,requires_pincode BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 RETURN QUERY SELECT m.plan_id,m.name,m.percentage,m.description,m.is_active,m.created_at,m.updated_at,COALESCE(m.post_price,0),COALESCE(m.document_processing_fee_enabled,FALSE),m.display_order,COALESCE(m.requires_payout_account,FALSE),COALESCE(m.strike_price,0),COALESCE(m.requires_pincode,FALSE)
 FROM public.management_service_plans m
 WHERE p_is_active_filter IS NULL OR m.is_active=p_is_active_filter
 ORDER BY (COALESCE(m.post_price,0)<=0),m.display_order,m.created_at,m.name;
END; $$;
REVOKE ALL ON FUNCTION public.list_management_plans_ordered(BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_management_plans_ordered(BOOLEAN) TO anon, authenticated;
