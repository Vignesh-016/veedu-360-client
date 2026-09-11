-- Restore the prior return shape; the column itself is intentionally preserved.
DROP FUNCTION IF EXISTS public.list_management_plans_ordered(BOOLEAN);
CREATE FUNCTION public.list_management_plans_ordered(p_is_active_filter BOOLEAN DEFAULT TRUE)
RETURNS TABLE (plan_id UUID, name TEXT, percentage NUMERIC, description TEXT, is_active BOOLEAN,
  created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ, post_price NUMERIC,
  document_processing_fee_enabled BOOLEAN, display_order INTEGER)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication is required.'; END IF;
  RETURN QUERY SELECT m.plan_id,m.name,m.percentage,m.description,m.is_active,m.created_at,m.updated_at,
    COALESCE(m.post_price,0),COALESCE(m.document_processing_fee_enabled,FALSE),m.display_order
  FROM public.management_service_plans m
  WHERE p_is_active_filter IS NULL OR m.is_active=p_is_active_filter
  ORDER BY (COALESCE(m.post_price,0)<=0),m.display_order,m.created_at,m.name;
END; $$;
GRANT EXECUTE ON FUNCTION public.list_management_plans_ordered(BOOLEAN) TO authenticated;
NOTIFY pgrst,'reload schema';
